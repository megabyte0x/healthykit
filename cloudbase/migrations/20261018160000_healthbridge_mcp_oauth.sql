-- HealthBridge OAuth state only. Encrypted by the application before persistence.
CREATE TABLE public.healthbridge_mcp_oauth (
  collection text NOT NULL,
  key_hash text NOT NULL CHECK(length(key_hash)=64),
  entry jsonb NOT NULL,
  expires_at timestamptz,
  PRIMARY KEY(collection,key_hash)
);
CREATE INDEX healthbridge_mcp_oauth_expiry ON public.healthbridge_mcp_oauth(expires_at);
ALTER TABLE public.healthbridge_mcp_oauth ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.healthbridge_mcp_oauth FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.healthbridge_mcp_oauth TO service_role;

CREATE FUNCTION public.healthbridge_oauth_kv(
  p_action text,p_collection text,p_key text,p_entry jsonb DEFAULT NULL,p_expires_at timestamptz DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v_entry jsonb; v_rows integer;
BEGIN
 IF p_collection IS NULL OR length(p_collection) NOT BETWEEN 1 AND 120 OR p_key IS NULL OR p_key !~ '^[0-9a-f]{64}$' THEN
   RAISE EXCEPTION 'Invalid OAuth storage key' USING ERRCODE='22023';
 END IF;
 IF p_action='get' THEN
   SELECT entry INTO v_entry FROM public.healthbridge_mcp_oauth
   WHERE collection=p_collection AND key_hash=p_key AND (expires_at IS NULL OR expires_at>clock_timestamp());
   RETURN jsonb_build_object('entry',v_entry);
 ELSIF p_action='put' THEN
   IF p_entry IS NULL OR pg_column_size(p_entry)>1048576 THEN
     RAISE EXCEPTION 'Invalid OAuth storage entry' USING ERRCODE='22023';
   END IF;
   DELETE FROM public.healthbridge_mcp_oauth WHERE expires_at<clock_timestamp();
   INSERT INTO public.healthbridge_mcp_oauth(collection,key_hash,entry,expires_at)
   VALUES(p_collection,p_key,p_entry,p_expires_at)
   ON CONFLICT(collection,key_hash) DO UPDATE SET entry=EXCLUDED.entry,expires_at=EXCLUDED.expires_at;
   RETURN jsonb_build_object('ok',true);
 ELSIF p_action='delete' THEN
   DELETE FROM public.healthbridge_mcp_oauth WHERE collection=p_collection AND key_hash=p_key;
   GET DIAGNOSTICS v_rows=ROW_COUNT;
   RETURN jsonb_build_object('deleted',v_rows>0);
 ELSE
   RAISE EXCEPTION 'Invalid OAuth storage action' USING ERRCODE='22023';
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.healthbridge_oauth_kv(text,text,text,jsonb,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.healthbridge_oauth_kv(text,text,text,jsonb,timestamptz) TO service_role;
