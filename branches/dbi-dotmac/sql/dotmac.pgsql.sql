--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: auth; Type: TABLE; Schema: public; Owner: dotmac; Tablespace: 
--

CREATE TABLE auth (
    username character varying(128),
    passwd character varying(255),
    realm character varying(128),
    idisk_quota_limit integer,
    mail_quota_limit integer,
    is_admin integer
);


ALTER TABLE public.auth OWNER TO dotmac;

--
-- Data for Name: auth; Type: TABLE DATA; Schema: public; Owner: dotmac
--

COPY auth (username, passwd, idisk_quota_limit, mail_quota_limit, is_admin) FROM stdin;
sean.nelson	c953915dcad4b1c20577b9e1ca677af4	4096000	1024000	1
\.


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

