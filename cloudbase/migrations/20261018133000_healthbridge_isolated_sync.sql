-- Health Bridge only. Never alters existing application tables or schema-wide grants.
CREATE TABLE public.healthbridge_batches (
  device_id text NOT NULL, export_id uuid NOT NULL, body_hash text NOT NULL,
  generated_at timestamptz NOT NULL, received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  timezone text NOT NULL, source text NOT NULL, schema_version integer NOT NULL,
  date_range jsonb NOT NULL, metric_count integer NOT NULL, workout_count integer NOT NULL,
  PRIMARY KEY(device_id, export_id), CHECK (length(body_hash)=64)
);
CREATE TABLE public.healthbridge_records (
  device_id text NOT NULL, kind text NOT NULL CHECK(kind IN ('metric','workout')),
  id text NOT NULL, sample_type text NOT NULL, start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL, timezone text NOT NULL, record jsonb NOT NULL,
  export_id uuid NOT NULL, PRIMARY KEY(device_id,kind,id), CHECK(end_at >= start_at)
);
CREATE INDEX healthbridge_records_type_time ON public.healthbridge_records(kind,sample_type,start_at DESC,id,device_id);
CREATE TABLE public.healthbridge_deletions (
  device_id text NOT NULL, kind text NOT NULL CHECK(kind IN ('metric','workout')),
  id text NOT NULL, received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY(device_id,kind,id)
);
ALTER TABLE public.healthbridge_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.healthbridge_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.healthbridge_deletions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.healthbridge_batches,public.healthbridge_records,public.healthbridge_deletions FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.healthbridge_batches,public.healthbridge_records,public.healthbridge_deletions TO service_role;

CREATE FUNCTION public.healthbridge_ingest(p_batch jsonb,p_hash text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE
 v_device text := p_batch->>'device_id'; v_export uuid := (p_batch->>'export_id')::uuid;
 v_old_hash text; v_item jsonb; v_kind text; v_received integer := 0;
 v_duplicates integer := 0; v_deleted integer := 0; v_rows integer;
 v_count integer := jsonb_array_length(coalesce(p_batch->'metrics','[]'::jsonb)) + jsonb_array_length(coalesce(p_batch->'workouts','[]'::jsonb));
BEGIN
 IF length(v_device) NOT BETWEEN 1 AND 128 OR length(p_hash)<>64 OR v_count>1000 THEN
   RAISE EXCEPTION 'Invalid health batch' USING ERRCODE='22023';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('healthbridge:' || v_device,0));
 SELECT body_hash INTO v_old_hash FROM public.healthbridge_batches WHERE device_id=v_device AND export_id=v_export;
 IF FOUND THEN
   IF v_old_hash<>p_hash THEN RAISE EXCEPTION 'Export ID reused with different content' USING ERRCODE='23505'; END IF;
   RETURN jsonb_build_object('ok',true,'received',0,'duplicates',v_count,'deleted',0);
 END IF;
 INSERT INTO public.healthbridge_batches(device_id,export_id,body_hash,generated_at,timezone,source,schema_version,date_range,metric_count,workout_count)
 VALUES(v_device,v_export,p_hash,(p_batch->>'generated_at')::timestamptz,p_batch->>'timezone',p_batch->>'source',(p_batch->>'schema_version')::integer,p_batch->'date_range',jsonb_array_length(p_batch->'metrics'),jsonb_array_length(p_batch->'workouts'));
 FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(p_batch->'deletions','[]'::jsonb)) LOOP
   INSERT INTO public.healthbridge_deletions(device_id,kind,id) VALUES(v_device,v_item->>'kind',v_item->>'id') ON CONFLICT DO NOTHING;
   DELETE FROM public.healthbridge_records WHERE device_id=v_device AND kind=v_item->>'kind' AND id=v_item->>'id';
   GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted:=v_deleted+v_rows;
 END LOOP;
 FOREACH v_kind IN ARRAY ARRAY['metric','workout'] LOOP
   FOR v_item IN SELECT value FROM jsonb_array_elements(p_batch->(CASE WHEN v_kind='metric' THEN 'metrics' ELSE 'workouts' END)) LOOP
     IF EXISTS(SELECT 1 FROM public.healthbridge_deletions WHERE device_id=v_device AND kind=v_kind AND id=v_item->>'id') THEN
       v_duplicates:=v_duplicates+1; CONTINUE;
     END IF;
     INSERT INTO public.healthbridge_records(device_id,kind,id,sample_type,start_at,end_at,timezone,record,export_id)
     VALUES(v_device,v_kind,v_item->>'id',coalesce(v_item->>'type',v_item->>'activity_type'),(v_item->>'start_at')::timestamptz,(v_item->>'end_at')::timestamptz,p_batch->>'timezone',v_item,v_export)
     ON CONFLICT DO NOTHING;
     GET DIAGNOSTICS v_rows = ROW_COUNT;
     v_received:=v_received+v_rows; v_duplicates:=v_duplicates+1-v_rows;
   END LOOP;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'received',v_received,'duplicates',v_duplicates,'deleted',v_deleted);
END $$;

CREATE FUNCTION public.healthbridge_read(p_kind text,p_type text DEFAULT NULL,p_from timestamptz DEFAULT NULL,p_to timestamptz DEFAULT NULL,p_limit integer DEFAULT 100,p_offset integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v_items jsonb; v_total bigint;
BEGIN
 IF p_limit NOT BETWEEN 1 AND 500 OR p_offset<0 OR p_kind NOT IN ('metric','workout','sync') THEN
   RAISE EXCEPTION 'Invalid query' USING ERRCODE='22023';
 END IF;
 IF p_kind='sync' THEN
   SELECT count(*) INTO v_total FROM public.healthbridge_batches WHERE (p_from IS NULL OR received_at>=p_from) AND (p_to IS NULL OR received_at<p_to);
   SELECT coalesce(jsonb_agg(x.item ORDER BY x.received_at DESC,x.export_id),'[]'::jsonb) INTO v_items FROM (
     SELECT received_at,export_id,jsonb_build_object('device_id',device_id,'export_id',export_id,'generated_at',generated_at,'received_at',received_at,'timezone',timezone,'source',source,'schema_version',schema_version,'date_range_start',date_range->>'start','date_range_end',date_range->>'end','metrics_count',metric_count,'workouts_count',workout_count) item
     FROM public.healthbridge_batches WHERE (p_from IS NULL OR received_at>=p_from) AND (p_to IS NULL OR received_at<p_to)
     ORDER BY received_at DESC,export_id LIMIT p_limit OFFSET p_offset
   ) x;
 ELSE
   SELECT count(*) INTO v_total FROM public.healthbridge_records WHERE kind=p_kind AND (p_type IS NULL OR sample_type=p_type) AND (p_from IS NULL OR start_at>=p_from) AND (p_to IS NULL OR start_at<p_to);
   SELECT coalesce(jsonb_agg(x.item ORDER BY x.start_at DESC,x.id,x.device_id),'[]'::jsonb) INTO v_items FROM (
     SELECT start_at,id,device_id,record || jsonb_build_object('device_id',device_id,'export_id',export_id,'timezone',timezone,'local_date',(start_at AT TIME ZONE timezone)::date) item
     FROM public.healthbridge_records WHERE kind=p_kind AND (p_type IS NULL OR sample_type=p_type) AND (p_from IS NULL OR start_at>=p_from) AND (p_to IS NULL OR start_at<p_to)
     ORDER BY start_at DESC,id,device_id LIMIT p_limit OFFSET p_offset
   ) x;
 END IF;
 RETURN jsonb_build_object('items',v_items,'page',jsonb_build_object('limit',p_limit,'offset',p_offset,'has_more',v_total>p_offset+p_limit));
END $$;
REVOKE ALL ON FUNCTION public.healthbridge_ingest(jsonb,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.healthbridge_read(text,text,timestamptz,timestamptz,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.healthbridge_ingest(jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.healthbridge_read(text,text,timestamptz,timestamptz,integer,integer) TO service_role;
-- Rollback is deliberately not automatic: drop only these healthbridge_* objects after exporting their data.
