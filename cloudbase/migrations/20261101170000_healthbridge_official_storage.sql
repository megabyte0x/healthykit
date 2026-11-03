-- Additive repository ports; existing records, tombstones and OAuth state stay in place.
CREATE FUNCTION public.healthbridge_read_official(p_kind text,p_type text DEFAULT NULL,p_device text DEFAULT NULL,p_from timestamptz DEFAULT NULL,p_to timestamptz DEFAULT NULL,p_limit integer DEFAULT 100,p_offset integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v_items jsonb; v_more boolean;
BEGIN
 IF p_limit NOT BETWEEN 1 AND 500 OR p_offset<0 OR p_kind NOT IN ('metric','workout','sync') THEN
  RAISE EXCEPTION 'Invalid query' USING ERRCODE='22023';
 END IF;
 IF p_kind='sync' THEN
  SELECT coalesce(jsonb_agg(q.item ORDER BY q.received_at DESC,q.export_id),'[]'::jsonb),count(*)>p_limit INTO v_items,v_more FROM (
   SELECT * FROM (
    SELECT received_at,export_id,jsonb_build_object('device_id',device_id,'export_id',export_id,'generated_at',generated_at,'received_at',received_at,'timezone',timezone,'source',source,'schema_version',schema_version,'date_range_start',date_range->>'start','date_range_end',date_range->>'end','metrics_count',metric_count,'workouts_count',workout_count) item
    FROM public.healthbridge_batches
    WHERE (p_device IS NULL OR device_id=p_device)
     AND (p_from IS NULL OR (date_range->>'end')::timestamptz>=p_from)
     AND (p_to IS NULL OR (date_range->>'start')::timestamptz<=p_to)
    ORDER BY received_at DESC,export_id LIMIT p_limit+1 OFFSET p_offset
   ) rows
  ) q;
 ELSE
  SELECT coalesce(jsonb_agg(q.item ORDER BY q.start_at DESC,q.device_id,q.id),'[]'::jsonb),count(*)>p_limit INTO v_items,v_more FROM (
   SELECT start_at,device_id,id,record || jsonb_build_object('device_id',device_id,'export_id',export_id,'timezone',timezone,'local_date',(start_at AT TIME ZONE timezone)::date) item
   FROM public.healthbridge_records WHERE kind=p_kind
    AND (p_type IS NULL OR sample_type=p_type) AND (p_device IS NULL OR device_id=p_device)
    AND (p_from IS NULL OR start_at>=p_from) AND (p_to IS NULL OR end_at<=p_to)
   ORDER BY start_at DESC,device_id,id LIMIT p_limit+1 OFFSET p_offset
  ) q;
 END IF;
 RETURN jsonb_build_object('items',CASE WHEN v_more THEN v_items - p_limit ELSE v_items END,
  'page',jsonb_build_object('limit',p_limit,'offset',p_offset,'has_more',coalesce(v_more,false)));
END $$;
CREATE FUNCTION public.healthbridge_catalog() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
 SELECT jsonb_build_object(
 'metric_types',coalesce((SELECT jsonb_agg(t ORDER BY t) FROM (SELECT DISTINCT sample_type t FROM public.healthbridge_records WHERE kind='metric') x),'[]'::jsonb),
 'activity_types',coalesce((SELECT jsonb_agg(t ORDER BY t) FROM (SELECT DISTINCT sample_type t FROM public.healthbridge_records WHERE kind='workout') x),'[]'::jsonb),
 'timezones',coalesce((SELECT jsonb_agg(t ORDER BY t) FROM (SELECT DISTINCT timezone t FROM public.healthbridge_batches) x),'[]'::jsonb),
 'devices',coalesce((SELECT jsonb_agg(jsonb_build_object('device_id',t,'label',NULL) ORDER BY t) FROM (SELECT DISTINCT device_id t FROM public.healthbridge_batches) x),'[]'::jsonb));
$$;
REVOKE ALL ON FUNCTION public.healthbridge_read_official(text,text,text,timestamptz,timestamptz,integer,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.healthbridge_catalog() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.healthbridge_read_official(text,text,text,timestamptz,timestamptz,integer,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.healthbridge_catalog() TO service_role;
