--
-- PostgreSQL database dump
--

\restrict U6efWeeoDM6yAUveRcakwjb4fDR7QNkMWjzIkOoSnrw85L9A3cFZMrdmxz7BMgA

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

--
-- Data for Name: config_match_ambiguities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.config_match_ambiguities (id, config_source, lookup_key, candidate_config_ids, chosen_config_id, occurrence_count, detected_at) FROM stdin;
\.


--
-- Data for Name: summary_totals; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.summary_totals (source_type, summary_field, positive_amount, negative_amount, record_count) FROM stdin;
payment	expenses_fba_fees	0.00	-495.05	2
settlement	refunded_expenses	289.82	-73.54	160
settlement	refunded_sales	0.00	-2031.37	94
settlement	sales_inventory_reimbursements	679.69	0.00	43
settlement	expenses_amazon_fees	0.00	-132593.41	24437
settlement	expenses_promotional_rebates	0.00	-11273.53	4193
settlement	sales_shipping	8875.84	-674.88	7386
settlement	sales_product_charges	349102.67	-193.90	18613
payment	refunded_sales	0.00	-3900.61	194
payment	refunded_expenses	526.76	0.00	158
payment	expenses_promotional_rebates	0.00	-25108.38	8288
payment	sales_shipping	20658.21	-341.93	6722
payment	sales_inventory_reimbursements	1668.36	0.00	97
payment	sales_other	33.19	0.00	9
payment	sales_product_charges	607702.61	0.00	31842
payment	expenses_cost_of_advertising	0.00	-1150.53	2
payment	expenses_amazon_fees	0.00	-217636.15	37639
settlement	expenses_fba_fees	0.00	-0.41	2
settlement	sales_other	11.97	0.00	4
\.


--
-- Name: config_match_ambiguities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.config_match_ambiguities_id_seq', 1, false);


--
-- PostgreSQL database dump complete
--

\unrestrict U6efWeeoDM6yAUveRcakwjb4fDR7QNkMWjzIkOoSnrw85L9A3cFZMrdmxz7BMgA

