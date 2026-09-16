--
-- PostgreSQL database dump
--

\restrict iz6Y7dU0HaabdJjUGbEE27uGe4Si8naguGbhJTOwZtJL7fRBZB3bE5dvxckg2DP

-- Dumped from database version 16.15 (Debian 16.15-1.pgdg13+2)
-- Dumped by pg_dump version 16.15 (Debian 16.15-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: config_match_ambiguities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.config_match_ambiguities (
    id integer NOT NULL,
    config_source text NOT NULL,
    lookup_key text NOT NULL,
    candidate_config_ids integer[] NOT NULL,
    chosen_config_id integer NOT NULL,
    occurrence_count integer DEFAULT 0 NOT NULL,
    detected_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: config_match_ambiguities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.config_match_ambiguities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: config_match_ambiguities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.config_match_ambiguities_id_seq OWNED BY public.config_match_ambiguities.id;


--
-- Name: payment_mapping_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_mapping_configs (
    id integer NOT NULL,
    source_line integer NOT NULL,
    transaction_type text DEFAULT ''::text NOT NULL,
    description text NOT NULL,
    amount_field text NOT NULL,
    record_ref_template text NOT NULL,
    summary_field_positive text DEFAULT ''::text NOT NULL,
    summary_field_negative text DEFAULT ''::text NOT NULL,
    loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: payment_mapping_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_mapping_configs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_mapping_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_mapping_configs_id_seq OWNED BY public.payment_mapping_configs.id;


--
-- Name: raw_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_records (
    id bigint NOT NULL,
    source_type text NOT NULL,
    source_file text NOT NULL,
    source_line integer NOT NULL,
    raw_payload jsonb NOT NULL,
    transaction_type text,
    description text,
    amount_type text,
    amount_description text,
    amount_field text,
    amount numeric(18,2) NOT NULL,
    order_id text,
    sku text,
    settlement_id text,
    shipment_id text,
    merchant_order_id text,
    txn_date date,
    record_ref text,
    matched_config_id integer,
    matched_config_source text,
    summary_field text,
    match_ambiguous boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT raw_records_matched_config_source_check CHECK ((matched_config_source = ANY (ARRAY['payment'::text, 'settlement'::text]))),
    CONSTRAINT raw_records_source_type_check CHECK ((source_type = ANY (ARRAY['payment'::text, 'settlement'::text])))
);


--
-- Name: raw_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.raw_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.raw_records_id_seq OWNED BY public.raw_records.id;


--
-- Name: reconciliation_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reconciliation_results (
    record_ref text NOT NULL,
    payment_amount numeric(18,2) DEFAULT 0 NOT NULL,
    settlement_amount numeric(18,2) DEFAULT 0 NOT NULL,
    difference numeric(18,2) DEFAULT 0 NOT NULL,
    payment_row_count integer DEFAULT 0 NOT NULL,
    settlement_row_count integer DEFAULT 0 NOT NULL,
    status text NOT NULL,
    computed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reconciliation_results_status_check CHECK ((status = ANY (ARRAY['reconciled'::text, 'unreconciled_payment'::text, 'unreconciled_settlement'::text])))
);


--
-- Name: settlement_mapping_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settlement_mapping_configs (
    id integer NOT NULL,
    source_line integer NOT NULL,
    transaction_type text DEFAULT ''::text NOT NULL,
    amount_type text NOT NULL,
    amount_description text NOT NULL,
    record_ref_template text NOT NULL,
    summary_field_positive text DEFAULT ''::text NOT NULL,
    summary_field_negative text DEFAULT ''::text NOT NULL,
    loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: settlement_mapping_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.settlement_mapping_configs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: settlement_mapping_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.settlement_mapping_configs_id_seq OWNED BY public.settlement_mapping_configs.id;


--
-- Name: summary_totals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.summary_totals (
    source_type text NOT NULL,
    summary_field text NOT NULL,
    positive_amount numeric(18,2) DEFAULT 0 NOT NULL,
    negative_amount numeric(18,2) DEFAULT 0 NOT NULL,
    record_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT summary_totals_source_type_check CHECK ((source_type = ANY (ARRAY['payment'::text, 'settlement'::text])))
);


--
-- Name: config_match_ambiguities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.config_match_ambiguities ALTER COLUMN id SET DEFAULT nextval('public.config_match_ambiguities_id_seq'::regclass);


--
-- Name: payment_mapping_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_mapping_configs ALTER COLUMN id SET DEFAULT nextval('public.payment_mapping_configs_id_seq'::regclass);


--
-- Name: raw_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_records ALTER COLUMN id SET DEFAULT nextval('public.raw_records_id_seq'::regclass);


--
-- Name: settlement_mapping_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_mapping_configs ALTER COLUMN id SET DEFAULT nextval('public.settlement_mapping_configs_id_seq'::regclass);


--
-- Name: config_match_ambiguities config_match_ambiguities_config_source_lookup_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.config_match_ambiguities
    ADD CONSTRAINT config_match_ambiguities_config_source_lookup_key_key UNIQUE (config_source, lookup_key);


--
-- Name: config_match_ambiguities config_match_ambiguities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.config_match_ambiguities
    ADD CONSTRAINT config_match_ambiguities_pkey PRIMARY KEY (id);


--
-- Name: payment_mapping_configs payment_mapping_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_mapping_configs
    ADD CONSTRAINT payment_mapping_configs_pkey PRIMARY KEY (id);


--
-- Name: raw_records raw_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_records
    ADD CONSTRAINT raw_records_pkey PRIMARY KEY (id);


--
-- Name: reconciliation_results reconciliation_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_results
    ADD CONSTRAINT reconciliation_results_pkey PRIMARY KEY (record_ref);


--
-- Name: settlement_mapping_configs settlement_mapping_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_mapping_configs
    ADD CONSTRAINT settlement_mapping_configs_pkey PRIMARY KEY (id);


--
-- Name: summary_totals summary_totals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.summary_totals
    ADD CONSTRAINT summary_totals_pkey PRIMARY KEY (source_type, summary_field);


--
-- Name: idx_raw_records_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_records_order_id ON public.raw_records USING btree (order_id);


--
-- Name: idx_raw_records_payload_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_records_payload_gin ON public.raw_records USING gin (raw_payload);


--
-- Name: idx_raw_records_record_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_records_record_ref ON public.raw_records USING btree (record_ref);


--
-- Name: idx_raw_records_ref_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_records_ref_source_id ON public.raw_records USING btree (record_ref, source_type, id);


--
-- Name: idx_raw_records_settlement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_records_settlement ON public.raw_records USING btree (settlement_id);


--
-- Name: idx_raw_records_source_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_raw_records_source_type ON public.raw_records USING btree (source_type);


--
-- PostgreSQL database dump complete
--

\unrestrict iz6Y7dU0HaabdJjUGbEE27uGe4Si8naguGbhJTOwZtJL7fRBZB3bE5dvxckg2DP

