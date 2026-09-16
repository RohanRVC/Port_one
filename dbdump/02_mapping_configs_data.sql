--
-- PostgreSQL database dump
--

\restrict mGXkhrAuuCfy4qhXtSRLmswzr2DYmUdKOCCjak41it2Ovj2nHwk94XTwh9Jp2Cx

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
-- Data for Name: payment_mapping_configs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payment_mapping_configs (id, source_line, transaction_type, description, amount_field, record_ref_template, summary_field_positive, summary_field_negative, loaded_at) FROM stdin;
1	2	ADJUSTMENT	COMMISSION_ADJUSTMENT	total	ADJUSTMENT_OTHER+settlement_id+date			2026-09-16 17:17:29.601355+00
2	3	ORDER_RETROCHARGE	any	low_value_goods	txn_ref+ORDER_RETROCHARGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.601355+00
3	4	REFUND	any	low_value_goods	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
4	5	ORDER	any	low_value_goods	txn_ref+sku+date	sales_shipping	sales_shipping	2026-09-16 17:17:29.601355+00
6	7	SERVICE_FEE	AWD_STORAGE_FEES	total	txn_ref+AWD_STORAGE_FEES+settlement_id+date			2026-09-16 17:17:29.601355+00
7	8	DEALS	any	total	txn_ref+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.601355+00
8	9	REFUND	any	product_sales	txn_ref+sku+date	refunded_sales	refunded_sales	2026-09-16 17:17:29.601355+00
9	10	REFUND	any	shipping_credits	txn_ref+sku+date	refunded_sales	refunded_sales	2026-09-16 17:17:29.601355+00
10	11	REFUND	any	fba_fees	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.601355+00
11	12	REFUND	any	other_transaction_fees	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.601355+00
12	13	REFUND	any	marketplace_withheld_tax	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
13	14	REFUND	any	sales_tax_collected	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
14	15	REFUND	any	gift_wrap_credits	txn_ref+sku+date	total_refund_expense_or_sales_amt	total_refund_expense_or_sales_amt	2026-09-16 17:17:29.601355+00
15	16	REFUND	any	other	txn_ref+sku+date	total_refund_expense_or_sales_amt	total_refund_expense_or_sales_amt	2026-09-16 17:17:29.601355+00
16	17	REFUND	any	promotional_rebates	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.601355+00
17	18	REFUND	any	selling_fees	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.601355+00
18	19	REFUND	any	total	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
19	20	ADJUSTMENT	BUYER_RECHARGE	other	ADJUSTMENT_BUYER_RECHARGE+settlement_id+date	total_adjustment_other_buyer_recharge_amt	total_adjustment_other_buyer_recharge_amt	2026-09-16 17:17:29.601355+00
20	21	ADJUSTMENT	BUYER_RECHARGE	total	ADJUSTMENT_BUYER_RECHARGE+settlement_id+date			2026-09-16 17:17:29.601355+00
21	22	ADJUSTMENT	NON-SUBSCRIPTION_FEE_ADJUSTMENT	other	ADJUSTMENT_NON_SUBSCRIPTION_FEE_ADJUSTMENT+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.601355+00
22	23	ADJUSTMENT	NON-SUBSCRIPTION_FEE_ADJUSTMENT	total	ADJUSTMENT_NON_SUBSCRIPTION_FEE_ADJUSTMENT+settlement_id+date			2026-09-16 17:17:29.601355+00
23	24	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_LOST:WAREHOUSE	other	LOST:WAREHOUSE+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.601355+00
24	25	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_LOST:WAREHOUSE	total	LOST:WAREHOUSE+sku+settlement_id+date			2026-09-16 17:17:29.601355+00
25	26	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_GENERAL_ADJUSTMENT	other	GENERAL ADJUSTMENT+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.601355+00
26	27	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_GENERAL_ADJUSTMENT	total	GENERAL ADJUSTMENT+sku+settlement_id+date			2026-09-16 17:17:29.601355+00
27	28	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_CUSTOMER_RETURN	other	txn_ref+sku+ADJUSTMENT+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.601355+00
28	29	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_CUSTOMER_RETURN	total	txn_ref+sku+ADJUSTMENT+settlement_id+date			2026-09-16 17:17:29.601355+00
29	30	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_FEE_CORRECTION	total	FBA_INVENTORY_REIMBURSEMENT_FEE_CORRECTION+settlement_id+date			2026-09-16 17:17:29.601355+00
31	32	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_LOST:INBOUND	other	LOST:INBOUND+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.601355+00
32	33	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_LOST:INBOUND	total	LOST:INBOUND+sku+settlement_id+date			2026-09-16 17:17:29.601355+00
33	34	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_DAMAGED:WAREHOUSE	other	DAMAGED:WAREHOUSE+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.601355+00
34	35	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_DAMAGED:WAREHOUSE	total	DAMAGED:WAREHOUSE+sku+settlement_id+date			2026-09-16 17:17:29.601355+00
35	36	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_CUSTOMER_SERVICE_ISSUE	other	txn_ref+sku+ADJUSTMENT+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.601355+00
36	37	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_CUSTOMER_SERVICE_ISSUE	total	txn_ref+sku+ADJUSTMENT+settlement_id+date			2026-09-16 17:17:29.601355+00
37	38	ADJUSTMENT	OTHER	other	ADJUSTMENT_OTHER+settlement_id+date	total_adjustment_other_buyer_recharge_amt	total_adjustment_other_buyer_recharge_amt	2026-09-16 17:17:29.601355+00
38	39	ADJUSTMENT	OTHER	total	ADJUSTMENT_OTHER+settlement_id+date			2026-09-16 17:17:29.601355+00
39	40	COMMINGLING_VAT	any	other	txn_ref+date	sales_tax	sales_tax	2026-09-16 17:17:29.601355+00
40	41	COMMINGLING_VAT	any	total	txn_ref+date			2026-09-16 17:17:29.601355+00
41	42	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_REMOVAL_ORDER:_RETURN_FEE	other	txn_ref+FBA_RETURN_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
42	43	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_REMOVAL_ORDER:_RETURN_FEE	total	txn_ref+FBA_RETURN_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
43	44	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FULFILMENT_BY_AMAZON_REMOVAL_ORDER:_DISPOSAL_FEE	other	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
44	45	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FULFILMENT_BY_AMAZON_REMOVAL_ORDER:_DISPOSAL_FEE	total	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
45	46	FULFILMENT_BY_AMAZON_INVENTORY_FEE	CAPACITY_RESERVATION_FEE	fba_fees	CAPACITY_RESERVATION_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
46	47	FULFILMENT_BY_AMAZON_INVENTORY_FEE	CAPACITY_RESERVATION_FEE	total	CAPACITY_RESERVATION_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
47	48	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE	other	FBA_INVENTORY_FEE_FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
48	49	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE	total	FBA_INVENTORY_FEE_FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
49	50	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_LONG-TERM_STORAGE_FEE	other	FBA_INVENTORY_FEE_FBA_LONG-TERM_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
50	51	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_LONG-TERM_STORAGE_FEE	total	FBA_INVENTORY_FEE_FBA_LONG-TERM_STORAGE_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
51	52	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_STORAGE_FEE	other	FBA_INVENTORY_FEE_FBA_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
52	53	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_STORAGE_FEE	total	FBA_INVENTORY_FEE_FBA_STORAGE_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
53	54	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_REMOVAL_ORDER:_DISPOSAL_FEE	other	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
54	55	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_REMOVAL_ORDER:_DISPOSAL_FEE	total	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
55	56	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_DISPOSAL_FEE	other	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
56	57	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_DISPOSAL_FEE	total	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
57	58	SAFE-T_REIMBURSEMENT	SAFE-T_CLAIM_ID	total	txn_ref+sku+settlement_id+date			2026-09-16 17:17:29.601355+00
58	59	SAFE-T_REIMBURSEMENT	SAFE-T_CLAIM_ID	other	txn_ref+sku+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
59	60	TRANSFER	MICRO_DEPOSIT	total	MICRO_DEPOSIT+settlement_id+date			2026-09-16 17:17:29.601355+00
60	61	TRANSFER	MICRO_DEPOSIT	other	MICRO_DEPOSIT+settlement_id+date	bank_account_transfer_round_off	bank_account_transfer_round_off	2026-09-16 17:17:29.601355+00
63	64	ORDER	any	selling_fees	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.601355+00
65	66	ORDER	any	other_transaction_fees	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.601355+00
66	67	ORDER	any	product_sales	txn_ref+sku+date	sales_product_charges	sales_product_charges	2026-09-16 17:17:29.601355+00
67	68	ORDER	any	shipping_credits	txn_ref+sku+date	sales_shipping	sales_shipping	2026-09-16 17:17:29.601355+00
68	69	ORDER	any	total	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
70	71	ORDER	any	sales_tax_collected	txn_ref+sku+date	sales_product_charges	sales_product_charges	2026-09-16 17:17:29.601355+00
72	73	ORDER	any	fba_fees	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.601355+00
73	74	ORDER	any	marketplace_withheld_tax	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
74	75	A-TO-Z_GUARANTEE_CLAIM	any	product_sales	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.601355+00
75	76	A-TO-Z_GUARANTEE_CLAIM	any	selling_fees	txn_ref+sku+date	sales_amazon_fees	sales_amazon_fees	2026-09-16 17:17:29.601355+00
76	77	A-TO-Z_GUARANTEE_CLAIM	any	marketplace_withheld_tax	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
77	78	A-TO-Z_GUARANTEE_CLAIM	any	total	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
78	79	AMAZON_FEES	VINE_ENROLLMENT_FEE	selling_fees	AMAZON_FEES_VINE_ENROLLMENT_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.601355+00
79	80	AMAZON_FEES	VINE_ENROLLMENT_FEE	total	AMAZON_FEES_VINE_ENROLLMENT_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
82	83	SERVICE_FEE	INBOUND_DEFECT_FEE	fba_fees	txn_ref+INBOUND_DEFECT_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
83	84	SERVICE_FEE	INBOUND_DEFECT_FEE	total	txn_ref+INBOUND_DEFECT_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
84	85	SERVICE_FEE	COST_OF_ADVERTISING	other	SERVICE_FEE_COST_OF_ADVERTISING+settlement_id+date			2026-09-16 17:17:29.601355+00
85	86	SERVICE_FEE	COST_OF_ADVERTISING	other_transaction_fees	SERVICE_FEE_COST_OF_ADVERTISING+settlement_id+date			2026-09-16 17:17:29.601355+00
86	87	SERVICE_FEE	COST_OF_ADVERTISING	total	SERVICE_FEE_COST_OF_ADVERTISING+settlement_id+date	expenses_cost_of_advertising	expenses_cost_of_advertising	2026-09-16 17:17:29.601355+00
87	88	SERVICE_FEE	AWD_PROCESSING_FEES	total	txn_ref+SERVICE_FEE_AWD_PROCESSING_FEES+settlement_id+date			2026-09-16 17:17:29.601355+00
88	89	SERVICE_FEE	AWD_PROCESSING_FEES	fba_fees	txn_ref+SERVICE_FEE_AWD_PROCESSING_FEES+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
89	90	SERVICE_FEE	COUPON_REDEMPTION_FEE	total	txn_ref+SERVICE_FEE_COUPON_REDEMPTION_FEE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.601355+00
90	91	SERVICE_FEE	COUPON_REDEMPTION_FEE	other	txn_ref+SERVICE_FEE_COUPON_REDEMPTION_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
91	92	SERVICE_FEE	COUPON_REDEMPTION_FEE	other_transaction_fees	txn_ref+SERVICE_FEE_COUPON_REDEMPTION_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
92	93	SERVICE_FEE	AWD_STORAGE_FEES	fba_fees	txn_ref+AWD_STORAGE_FEES+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
93	94	SERVICE_FEE	AWD_TRANSPORTATION_FEES	fba_fees	txn_ref+SERVICE_FEE_AWD_TRANSPORTATION_FEES+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
94	95	SERVICE_FEE	AWD_TRANSPORTATION_FEES	total	txn_ref+SERVICE_FEE_AWD_TRANSPORTATION_FEES+settlement_id+date			2026-09-16 17:17:29.601355+00
95	96	SERVICE_FEE	FBA_INBOUND_PLACEMENT_SERVICE_FEE	other	txn_ref+SERVICE_FEE_FBA_INBOUND_PLACEMENT_SERVICE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
96	97	SERVICE_FEE	FBA_INBOUND_PLACEMENT_SERVICE_FEE	total	txn_ref+SERVICE_FEE_FBA_INBOUND_PLACEMENT_SERVICE_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
97	98	SERVICE_FEE	FBA_INTERNATIONAL_SHIPPING_CHARGE	other	txn_ref+FBA_INTERNATIONAL_SHIPPING_CHARGE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
98	99	SERVICE_FEE	FBA_INTERNATIONAL_SHIPPING_CHARGE	total	txn_ref+FBA_INTERNATIONAL_SHIPPING_CHARGE+settlement_id+date			2026-09-16 17:17:29.601355+00
99	100	SERVICE_FEE	SUBSCRIPTION	other	SERVICE_FEE_SUBSCRIPTION+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.601355+00
100	101	SERVICE_FEE	SUBSCRIPTION	total	SERVICE_FEE_SUBSCRIPTION+settlement_id+date			2026-09-16 17:17:29.601355+00
101	102	SERVICE_FEE	VINE_ENROLLMENT_FEE	other	txn_ref+VINE_ENROLLMENT_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.601355+00
102	103	SERVICE_FEE	VINE_ENROLLMENT_FEE	total	txn_ref+VINE_ENROLLMENT_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
103	104	SERVICE_FEE	PREMIUM_SERVICES_FEE	selling_fees	txn_ref+SERVICE_FEE_PREMIUM_SERVICES_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.601355+00
104	105	SERVICE_FEE	PREMIUM_SERVICES_FEE	total	txn_ref+SERVICE_FEE_PREMIUM_SERVICES_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
105	106	SHIPPING_SERVICES	RETURNPOSTAGEBILLING	total	txn_ref+SHIPPING_RETURN_POSTAGE+settlement_id+date			2026-09-16 17:17:29.601355+00
69	70	ORDER	any	gift_wrap_credits	txn_ref+sku+date	sales_other	sales_other	2026-09-16 17:17:29.601355+00
61	62	TRANSFER	any	total	TRANSFER+description+settlement_id+date			2026-09-16 17:17:29.601355+00
106	107	SHIPPING_SERVICES	RETURNPOSTAGEBILLING	other	txn_ref+SHIPPING_RETURN_POSTAGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.601355+00
107	108	SHIPPING_SERVICES	ADJUSTMENT	other	txn_ref+SHIPPING_ADJUSTMENT+settlement_id+date	sales_other	expenses_other	2026-09-16 17:17:29.601355+00
108	109	SHIPPING_SERVICES	ADJUSTMENT	total	txn_ref+SHIPPING_ADJUSTMENT+settlement_id+date			2026-09-16 17:17:29.601355+00
110	111		any	other	txn_ref+settlement_id+date			2026-09-16 17:17:29.601355+00
111	112		any	other_transaction_fees	txn_ref+settlement_id+date			2026-09-16 17:17:29.601355+00
112	113	CHARGEBACK_REFUND	any	fba_fees	txn_ref+sku+date	sales_amazon_fees	sales_amazon_fees	2026-09-16 17:17:29.601355+00
113	114	CHARGEBACK_REFUND	any	total	txn_ref+sku+date			2026-09-16 17:17:29.601355+00
114	115	CHARGEBACK_REFUND	any	selling_fees	txn_ref+sku+date	sales_amazon_fees	sales_amazon_fees	2026-09-16 17:17:29.601355+00
115	116	CHARGEBACK_REFUND	any	product_sales	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.601355+00
116	117	CHARGEBACK_REFUND	any	shipping_credits	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.601355+00
117	118	DEBT	any	other	OTHER_DEBT+settlement_id+date	paid_to_amazon	paid_to_amazon	2026-09-16 17:17:29.601355+00
118	119	DEBT	any	total	OTHER_DEBT+settlement_id+date			2026-09-16 17:17:29.601355+00
119	120	FBA_TRANSACTION_FEES	AWD_STORAGE_FEE	fba_fees	txn_ref+FBA_TRANSACTION_FEES_AWD_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
120	121	FBA_TRANSACTION_FEES	AWD_STORAGE_FEE	total	txn_ref+FBA_TRANSACTION_FEES_AWD_STORAGE_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
121	122	FBA_TRANSACTION_FEES	AWD_TRANSPORTATION_FEE	fba_fees	txn_ref+FBA_TRANSACTION_FEES_AWD_TRANSPORTATION_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
122	123	FBA_TRANSACTION_FEES	AWD_TRANSPORTATION_FEE	total	txn_ref+FBA_TRANSACTION_FEES_AWD_TRANSPORTATION_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
123	124	FBA_TRANSACTION_FEES	AWD_PROCESSING_FEE	fba_fees	txn_ref+FBA_TRANSACTION_FEES_AWD_PROCESSING_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
124	125	FBA_TRANSACTION_FEES	AWD_PROCESSING_FEE	total	txn_ref+FBA_TRANSACTION_FEES_AWD_PROCESSING_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
125	126	FBA_TRANSACTION_FEES	FBA_CUSTOMER_RETURNS_FEE	fba_fees	FBA_TRANSACTION_FEES_FBA_CUSTOMER_RETURNS_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
126	127	FBA_TRANSACTION_FEES	FBA_CUSTOMER_RETURNS_FEE	total	FBA_TRANSACTION_FEES_FBA_CUSTOMER_RETURNS_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
127	128	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_RETURN_FEE	other	txn_ref+FBA_RETURN_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
128	129	FULFILMENT_BY_AMAZON_INVENTORY_FEE	FBA_RETURN_FEE	total	txn_ref+FBA_RETURN_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
129	130	ORDER_RETROCHARGE	any	sales_tax_collected	txn_ref+ORDER_RETROCHARGE+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.601355+00
130	131	ORDER_RETROCHARGE	any	total	txn_ref+ORDER_RETROCHARGE+settlement_id+date			2026-09-16 17:17:29.601355+00
131	132	SERVICE_FEE	REFUND_FOR_ADVERTISER	other_transaction_fees	SERVICE_FEE_REFUND_FOR_ADVERTISER+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.601355+00
132	133	SERVICE_FEE	REFUND_FOR_ADVERTISER	other	SERVICE_FEE_REFUND_FOR_ADVERTISER+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.601355+00
133	134	SERVICE_FEE	REFUND_FOR_ADVERTISER	total	SERVICE_FEE_REFUND_FOR_ADVERTISER+settlement_id+date			2026-09-16 17:17:29.601355+00
134	135	ADJUSTMENT	FAILED_DISBURSEMENT	total	FAILED_DISBURSEMENT+description+settlement_id+date			2026-09-16 17:17:29.601355+00
135	136	OTHERS	SELLER_REWARDS	total	SELLER_REWARDS+settlement_id+date			2026-09-16 17:17:29.601355+00
136	137	OTHERS	SELLER_REWARDS	other	SELLER_REWARDS+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.601355+00
139	140	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FULFILMENT_BY_AMAZON_REMOVAL_ORDER:_DISPOSAL_FEE	total	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
140	141	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FULFILMENT_BY_AMAZON_REMOVAL_ORDER:_DISPOSAL_FEE	fba_fees	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
141	142	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FBA_REMOVAL_ORDER:_RETURN_FEE	total	txn_ref+FBA_RETURN_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
142	143	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FBA_REMOVAL_ORDER:_RETURN_FEE	fba_fees	txn_ref+FBA_RETURN_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
143	144	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FULFILMENT_BY_AMAZON_(FBA)_INVENTORY_STORAGE_FEE	total	FBA_INVENTORY_STORAGE_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
144	145	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FULFILMENT_BY_AMAZON_(FBA)_INVENTORY_STORAGE_FEE	fba_fees	FBA_INVENTORY_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
145	146	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FULFILMENT_BY_AMAZON_(FBA)_LONG-TERM_STORAGE_FEE	fba_fees	FBA_INVENTORY_FEE_FBA_LONG-TERM_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
146	147	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FULFILMENT_BY_AMAZON_(FBA)_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE	total	FBA_INVENTORY_FEE_FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
147	148	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FULFILMENT_BY_AMAZON_(FBA)_LONG-TERM_STORAGE_FEE	total	FBA_INVENTORY_FEE_FBA_LONG-TERM_STORAGE_FEE+settlement_id+date			2026-09-16 17:17:29.601355+00
148	149	FULFILMENT_BY_AMAZON_TRANSACTION_FEES	FULFILMENT_BY_AMAZON_(FBA)_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE	fba_fees	FBA_INVENTORY_FEE_FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.601355+00
149	150	ADJUSTMENT	COMMISSION_ADJUSTMENT	other	ADJUSTMENT_OTHER+settlement_id+date	total_adjustment_other_buyer_recharge_amt	total_adjustment_other_buyer_recharge_amt	2026-09-16 17:17:29.601355+00
64	65	ORDER	any	promotional_rebates	txn_ref+sku+date	expenses_promotional_rebates	expenses_promotional_rebates	2026-09-16 17:17:29.601355+00
109	110		any	total	txn_ref+settlement_id+date			2026-09-16 17:17:29.601355+00
137	138	ADJUSTMENT	MULTI-CHANNEL_FULFILMENT_INVENTORY_REIMBURSEMENT_LOST	other	txn_ref+sku+MCF_INVENTORY_REIMBURSEMENT_LOST+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.601355+00
138	139	ADJUSTMENT	MULTI-CHANNEL_FULFILMENT_INVENTORY_REIMBURSEMENT_LOST	total	txn_ref+sku+MCF_INVENTORY_REIMBURSEMENT_LOST+settlement_id+date			2026-09-16 17:17:29.601355+00
30	31	ADJUSTMENT	FBA_INVENTORY_REIMBURSEMENT_-_FEE_CORRECTION	other	FBA_INVENTORY_REIMBURSEMENT_FEE_CORRECTION+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.601355+00
\.


--
-- Data for Name: settlement_mapping_configs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.settlement_mapping_configs (id, source_line, transaction_type, amount_type, amount_description, record_ref_template, summary_field_positive, summary_field_negative, loaded_at) FROM stdin;
1	2	FBAFEES	AWD_STORAGE_FEE	DISCOUNT_ON_FEE	txn_ref+FBA_TRANSACTION_FEES_AWD_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
2	3	FBAFEES	AWD_PROCESSING_FEE	BASE_FEE	txn_ref+FBA_TRANSACTION_FEES_AWD_PROCESSING_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
4	5	REFUND	ITEMPRICE	GIFTWRAP	txn_ref+sku+date	total_refund_expense_or_sales_amt	total_refund_expense_or_sales_amt	2026-09-16 17:17:29.64661+00
5	6	REFUND	ITEMPRICE	GOODWILL	txn_ref+sku+date	total_refund_expense_or_sales_amt	total_refund_expense_or_sales_amt	2026-09-16 17:17:29.64661+00
6	7	REFUND	ITEMPRICE	RESTOCKINGFEE	txn_ref+sku+date	total_refund_expense_or_sales_amt	total_refund_expense_or_sales_amt	2026-09-16 17:17:29.64661+00
7	8	SERVICEFEE	REFUND_FOR_ADVERTISER	TRANSACTIONTOTALAMOUNT	SERVICE_FEE_REFUND_FOR_ADVERTISER+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
8	9	ORDER_RETROCHARGE	ITEMPRICE	TAX	txn_ref+ORDER_RETROCHARGE+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
9	10	REFUND	ITEMPRICE	SHIPPING	txn_ref+sku+date	refunded_sales	refunded_sales	2026-09-16 17:17:29.64661+00
10	11	REFUND	ITEMPRICE	SHIPPINGTAX	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
11	12	REFUND	ITEMPRICE	GIFTWRAPTAX	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
12	13	REFUND	ITEMPRICE	PRINCIPAL	txn_ref+sku+date	refunded_sales	refunded_sales	2026-09-16 17:17:29.64661+00
13	14	REFUND	ITEMFEES	REMOTEFULFILLMENTCREDIT	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
14	15	REFUND	ITEMFEES	GIFTWRAPCHARGEBACK	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
15	16	REFUND	ITEMFEES	SHIPPINGCHARGEBACK	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
16	17	REFUND	ITEMFEES	COMMISSION	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
17	18	REFUND	ITEMFEES	REFUNDCOMMISSION	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
18	19	REFUND	ITEMFEES	DIGITALSERVICESFEE	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
19	20	REFUND	PROMOTION	TAXDISCOUNT	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
20	21	REFUND	PROMOTION	PRINCIPAL	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
21	22	REFUND	PROMOTION	SHIPPING	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
22	23	OTHER-TRANSACTION	OTHER-TRANSACTION	DISPOSALCOMPLETE	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
23	24	OTHER-TRANSACTION	OTHER-TRANSACTION	FBA_INBOUND_PLACEMENT_SERVICE_FEE	shipment_id+SERVICE_FEE_FBA_INBOUND_PLACEMENT_SERVICE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
24	25	OTHER-TRANSACTION	OTHER-TRANSACTION	SUBSCRIPTION_FEE	SERVICE_FEE_SUBSCRIPTION+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
25	26	OTHER-TRANSACTION	OTHER-TRANSACTION	SHIPPING_LABEL_PURCHASE_FOR_RETURN	txn_ref+SHIPPING_RETURN_POSTAGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
26	27	OTHER-TRANSACTION	OTHER-TRANSACTION	FBAINBOUNDTRANSPORTATIONFEE	FBA_INVENTORY_FEE_FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
27	28	OTHER-TRANSACTION	OTHER-TRANSACTION	MISCADJUSTMENT	ADJUSTMENT_OTHER+settlement_id+date	total_adjustment_other_buyer_recharge_amt	total_adjustment_other_buyer_recharge_amt	2026-09-16 17:17:29.64661+00
28	29	FBAFEES	AWD_TRANSPORTATION_FEE	BASE_FEE	txn_ref+FBA_TRANSACTION_FEES_AWD_TRANSPORTATION_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
29	30	OTHER-TRANSACTION	OTHER-TRANSACTION	BUYERRECHARGE	ADJUSTMENT_BUYER_RECHARGE+settlement_id+date	total_adjustment_other_buyer_recharge_amt	total_adjustment_other_buyer_recharge_amt	2026-09-16 17:17:29.64661+00
30	31	OTHER-TRANSACTION	OTHER-TRANSACTION	CURRENT_RESERVE_AMOUNT	CURRENT_RESERVE_AMOUNT+settlement_id+date	current_reserve_amount	current_reserve_amount	2026-09-16 17:17:29.64661+00
31	32	OTHER-TRANSACTION	OTHER-TRANSACTION	SUCCESSFUL_CHARGE	OTHER_DEBT+settlement_id+date	paid_to_amazon	paid_to_amazon	2026-09-16 17:17:29.64661+00
32	33	OTHER-TRANSACTION	OTHER-TRANSACTION	PREVIOUS_RESERVE_AMOUNT_BALANCE	PREVIOUS_RESERVE_AMOUNT_BALANCE+settlement_id+date	beginning_balance	beginning_balance	2026-09-16 17:17:29.64661+00
33	34	OTHER-TRANSACTION	OTHER-TRANSACTION	REMOVALCOMPLETE	txn_ref+FBA_RETURN_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
34	35	OTHER-TRANSACTION	OTHER-TRANSACTION	AGSGLOBALINBOUNDTRANSPORTATION	txn_ref+FBA_INTERNATIONAL_SHIPPING_CHARGE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
35	36	OTHER-TRANSACTION	OTHER-TRANSACTION	STORAGE_FEE	FBA_INVENTORY_FEE_FBA_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
36	37	OTHER-TRANSACTION	OTHER-TRANSACTION	PAYABLE_TO_AMAZON	PAYABLE_TO_AMAZON+settlement_id+date	amazon_carried_forward	amazon_carried_forward	2026-09-16 17:17:29.64661+00
37	38	OTHER-TRANSACTION	OTHER-TRANSACTION	PAID_SERVICES_FEE	txn_ref+SERVICE_FEE_PREMIUM_SERVICES_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
38	39	OTHER-TRANSACTION	OTHER-TRANSACTION	NONSUBSCRIPTIONFEEADJ	ADJUSTMENT_NON_SUBSCRIPTION_FEE_ADJUSTMENT+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
39	40	OTHER-TRANSACTION	OTHER-TRANSACTION	STORAGERENEWALBILLING	FBA_INVENTORY_FEE_FBA_LONG-TERM_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
40	41	OTHER-TRANSACTION	OTHER-TRANSACTION	ADJUSTMENT	txn_ref+SHIPPING_ADJUSTMENT+settlement_id+date	sales_other	expenses_other	2026-09-16 17:17:29.64661+00
41	42	OTHER-TRANSACTION	OTHER-TRANSACTION	INCOME_TAX_CHARGED	INCOME_TAX_CHARGED+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
42	43	OTHER-TRANSACTION	CAPACITY_RESERVATION_FEE	PERFORMANCE_CREDITS	CAPACITY_RESERVATION_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
43	44	OTHER-TRANSACTION	CAPACITY_RESERVATION_FEE	RESERVATION_FEE	CAPACITY_RESERVATION_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
44	45	OTHER-TRANSACTION	CAPACITY_RESERVATION_FEE	TAX	CAPACITY_RESERVATION_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
45	46	OTHER-TRANSACTION	AMAZON_WAREHOUSING_&_DISTRIBUTION_(AWD)	AWD_TRANSPORTATION_FEE	txn_ref+SERVICE_FEE_AWD_TRANSPORTATION_FEES+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
46	47	OTHER-TRANSACTION	AMAZON_WAREHOUSING_&_DISTRIBUTION_(AWD)	AWD_PROCESSING_FEE	txn_ref+SERVICE_FEE_AWD_PROCESSING_FEES+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
47	48	OTHER-TRANSACTION	AMAZON_WAREHOUSING_&_DISTRIBUTION_(AWD)	AWD_STORAGE_FEE	txn_ref+AWD_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
48	49	OTHER-TRANSACTION	INBOUND_DEFECT_FEE	any	shipment_id+INBOUND_DEFECT_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
49	50	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	FREE_REPLACEMENT_REFUND_ITEMS	txn_ref+sku+ADJUSTMENT+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
50	51	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	REVERSAL_REIMBURSEMENT	txn_ref+sku+ADJUSTMENT+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
51	52	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	WAREHOUSE_LOST	LOST:WAREHOUSE+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
52	53	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	WAREHOUSE_DAMAGE_EXCEPTION	DAMAGED:WAREHOUSE+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
53	54	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	RE_EVALUATION	GENERAL ADJUSTMENT+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
54	55	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	WAREHOUSE_DAMAGE	DAMAGED:WAREHOUSE+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
55	56	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	MISSING_FROM_INBOUND_CLAWBACK	GENERAL ADJUSTMENT+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
56	57	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	MISSING_FROM_INBOUND	LOST:INBOUND+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
57	58	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	CS_ERROR_ITEMS	txn_ref+sku+ADJUSTMENT+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
58	59	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	WAREHOUSE_LOST_MANUAL	LOST:WAREHOUSE+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
59	60	TRANSFERS	MICRO_DEPOSIT	MICRO_DEPOSIT	MICRO_DEPOSIT+settlement_id+date	bank_account_transfer_round_off	bank_account_transfer_round_off	2026-09-16 17:17:29.64661+00
60	61	ORDER	ITEMPRICE	GIFTWRAPTAX	txn_ref+sku+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
61	62	ORDER	ITEMPRICE	SHIPPING	txn_ref+sku+date	sales_shipping	sales_shipping	2026-09-16 17:17:29.64661+00
62	63	ORDER	ITEMPRICE	SHIPPINGTAX	txn_ref+sku+date	sales_shipping	sales_shipping	2026-09-16 17:17:29.64661+00
63	64	ORDER	ITEMPRICE	PRINCIPAL	txn_ref+sku+date	sales_product_charges	sales_product_charges	2026-09-16 17:17:29.64661+00
64	65	ORDER	ITEMPRICE	TAX	txn_ref+sku+date	sales_product_charges	sales_product_charges	2026-09-16 17:17:29.64661+00
65	66	ORDER	ITEMPRICE	GIFTWRAP	txn_ref+sku+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
66	67	ORDER	ITEMFEES	FBAPERUNITFULFILLMENTFEE	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
67	68	ORDER	ITEMFEES	GIFTWRAPCHARGEBACK	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
68	69	ORDER	ITEMFEES	SHIPPINGCHARGEBACK	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
69	70	ORDER	ITEMFEES	COMMISSION	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
70	71	ORDER	ITEMFEES	DIGITALSERVICESFEE	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
71	72	ORDER	PROMOTION	PRINCIPAL	txn_ref+sku+date	expenses_promotional_rebates	expenses_promotional_rebates	2026-09-16 17:17:29.64661+00
72	73	ORDER	PROMOTION	SHIPPING	txn_ref+sku+date	expenses_promotional_rebates	expenses_promotional_rebates	2026-09-16 17:17:29.64661+00
73	74	ORDER	POINTS	POINTSGRANTED	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
74	75	COMMINGLING_VAT	OTHER-TRANSACTION	COMMINGLING_VAT	txn_ref+date	sales_tax	sales_tax	2026-09-16 17:17:29.64661+00
75	76	FBAFEES	FBA_CUSTOMER_RETURNS_FEE	BASE_FEE	FBA_TRANSACTION_FEES_FBA_CUSTOMER_RETURNS_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
76	77	FBAFEES	AWD_STORAGE_FEE	BASE_FEE	txn_ref+FBA_TRANSACTION_FEES_AWD_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
77	78	LIQUIDATIONS_ADJUSTMENTS	ITEMWITHHELDTAX	MARKETPLACEFACILITATORTAX-PRINCIPAL	txn_ref+sku+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
78	79	SAFE-T_REIMBURSEMENT	OTHER_TRANSACTIONS	SAFE-T_REIMBURSEMENT	txn_ref+sku+settlement_id+date	sales_inventory_reimbursements	sales_inventory_reimbursements	2026-09-16 17:17:29.64661+00
79	80	A-TO-Z_GUARANTEE_REFUND	ITEMWITHHELDTAX	MARKETPLACEFACILITATORTAX-PRINCIPAL	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
80	81	A-TO-Z_GUARANTEE_REFUND	ITEMPRICE	TAX	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
81	82	A-TO-Z_GUARANTEE_REFUND	ITEMPRICE	PRINCIPAL	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
82	83	A-TO-Z_GUARANTEE_REFUND	ITEMFEES	COMMISSION	txn_ref+sku+date	sales_amazon_fees	sales_amazon_fees	2026-09-16 17:17:29.64661+00
83	84	A-TO-Z_GUARANTEE_REFUND	ITEMFEES	REFUNDCOMMISSION	txn_ref+sku+date	sales_amazon_fees	sales_amazon_fees	2026-09-16 17:17:29.64661+00
84	85	ORDER_RETROCHARGE	ITEMPRICE	SHIPPINGTAX	txn_ref+ORDER_RETROCHARGE+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
85	86	ORDER_RETROCHARGE	ITEMWITHHELDTAX	MARKETPLACEFACILITATORTAX-PRINCIPAL	txn_ref+ORDER_RETROCHARGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
86	87	ORDER_RETROCHARGE	ITEMWITHHELDTAX	MARKETPLACEFACILITATORTAX-SHIPPING	txn_ref+ORDER_RETROCHARGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
87	88	ORDER_RETROCHARGE	ITEMWITHHELDTAX	MARKETPLACEFACILITATORVAT-PRINCIPAL	txn_ref+ORDER_RETROCHARGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
88	89	ORDER_RETROCHARGE	ITEMWITHHELDTAX	MARKETPLACEFACILITATORVAT-SHIPPING	txn_ref+ORDER_RETROCHARGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
89	90	PROMOTION_FEE	PROMOTIONFEE	PROMOTION_FEE	merchant_order_id+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
90	91	PROMOTION_FEE	PROMOTIONFEE	PROMOTION_FEE_SPECIAL	merchant_order_id+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
91	92	PROMOTION_FEE	DEALS	PROMOTION_FEE	DEALS_PROMOTION_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
92	93	PROMOTION_FEE	DEALS	PROMOTION_FEE_SPECIAL	DEALS_PROMOTION_FEE_SPECIAL+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
93	94	REFUND_RETROCHARGE	ITEMPRICE	TAX	txn_ref+REFUND_RETROCHARGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
94	95	ORDER	PROMOTION	TAXDISCOUNT	txn_ref+sku+date	sales_shipping	sales_shipping	2026-09-16 17:17:29.64661+00
95	96	REFUND_RETROCHARGE	ITEMPRICE	SHIPPINGTAX	txn_ref+REFUND_RETROCHARGE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
96	97	REFUND_RETROCHARGE	ITEMWITHHELDTAX	MARKETPLACEFACILITATORTAX-SHIPPING	txn_ref+REFUND_RETROCHARGE+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
97	98	REFUND_RETROCHARGE	ITEMWITHHELDTAX	MARKETPLACEFACILITATORTAX-PRINCIPAL	txn_ref+REFUND_RETROCHARGE+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
98	99	VINE_ENROLLMENT_FEE	VINE_ENROLLMENT_FEE	VINE_ENROLLMENT_FEE	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
99	100	AMAZONFEES	VINE_ENROLLMENT_FEE	TAX_ON_FEE	AMAZON_FEES_VINE_ENROLLMENT_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
100	101	AMAZONFEES	VINE_ENROLLMENT_FEE	BASE_FEE	AMAZON_FEES_VINE_ENROLLMENT_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
101	102	AMAZONFEES	VINE_ENROLLMENT_FEE	DISCOUNT_ON_FEE	AMAZON_FEES_VINE_ENROLLMENT_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
102	103	CHARGEBACK_REFUND	ITEMWITHHELDTAX	MARKETPLACEFACILITATORTAX-PRINCIPAL	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
103	104	CHARGEBACK_REFUND	ITEMWITHHELDTAX	MARKETPLACEFACILITATORVAT-PRINCIPAL	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
104	105	CHARGEBACK_REFUND	ITEMWITHHELDTAX	MARKETPLACEFACILITATORVAT-SHIPPING	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
105	106	CHARGEBACK_REFUND	ITEMPRICE	PRINCIPAL	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
106	107	CHARGEBACK_REFUND	ITEMPRICE	TAX	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
107	108	CHARGEBACK_REFUND	ITEMPRICE	SHIPPING	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
108	109	CHARGEBACK_REFUND	ITEMPRICE	SHIPPINGTAX	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
109	110	CHARGEBACK_REFUND	ITEMFEES	SHIPPINGCHARGEBACK	txn_ref+sku+date	sales_amazon_fees	sales_amazon_fees	2026-09-16 17:17:29.64661+00
110	111	CHARGEBACK_REFUND	ITEMFEES	COMMISSION	txn_ref+sku+date	sales_amazon_fees	sales_amazon_fees	2026-09-16 17:17:29.64661+00
111	112	CHARGEBACK_REFUND	ITEMFEES	REFUNDCOMMISSION	txn_ref+sku+date	sales_amazon_fees	sales_amazon_fees	2026-09-16 17:17:29.64661+00
112	113	COUPONREDEMPTIONFEE	COUPONREDEMPTIONFEE	any	txn_ref+SERVICE_FEE_COUPON_REDEMPTION_FEE+settlement_id+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
113	114	SERVICEFEE	COST_OF_ADVERTISING	TRANSACTIONTOTALAMOUNT	SERVICE_FEE_COST_OF_ADVERTISING+settlement_id+date	expenses_cost_of_advertising	expenses_cost_of_advertising	2026-09-16 17:17:29.64661+00
114	115	SERVICEFEE	DEALS	PROMOTION_FEE	DEALS_PROMOTION_FEE+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
115	116	SERVICEFEE	DEALS	PROMOTION_FEE_SPECIAL	DEALS_PROMOTION_FEE_SPECIAL+settlement_id+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
116	117	ORDER	ITEMFEES	SALESTAXSERVICEFEE	txn_ref+sku+date	expenses_amazon_fees	expenses_amazon_fees	2026-09-16 17:17:29.64661+00
117	118	ORDER	ITEMWITHHELDTAX	LOWVALUEGOODSTAX-SHIPPING	txn_ref+sku+date	sales_shipping	sales_shipping	2026-09-16 17:17:29.64661+00
118	119	ORDER	ITEMWITHHELDTAX	LOWVALUEGOODSTAX-PRINCIPAL	txn_ref+sku+date	sales_product_charges	sales_product_charges	2026-09-16 17:17:29.64661+00
119	120	REFUND	ITEMWITHHELDTAX	any	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
120	121	REFUND	ITEMPRICE	RETURNSHIPPING	txn_ref+sku+date	refunded_expenses	refunded_expenses	2026-09-16 17:17:29.64661+00
121	122	OTHER-TRANSACTION	FBA_INVENTORY_REIMBURSEMENT	COMPENSATED_CLAWBACK	GENERAL ADJUSTMENT+sku+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
122	123	LIQUIDATIONS_ADJUSTMENTS	ITEMPRICE	TAX	txn_ref+sku+date	expenses_other	expenses_other	2026-09-16 17:17:29.64661+00
124	125	SELLER_REWARDS	SELLER_REWARDS	SELLER_REWARDS	SELLER_REWARDS+settlement_id+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
125	126	OTHER-TRANSACTION	MCF_INVENTORY_REIMBURSEMENT	MULTICHANNEL_ORDER_LOST	txn_ref+sku+MCF_INVENTORY_REIMBURSEMENT_LOST+settlement_id+date	sales_inventory_reimbursements	expenses_reversed_reimbursements	2026-09-16 17:17:29.64661+00
126	127	ORDER	ITEMWITHHELDTAX	LOWVALUEGOODSTAX-OTHER	txn_ref+sku+date	sales_other	sales_other	2026-09-16 17:17:29.64661+00
127	128	FBAFEES	FBA_REMOVAL_ORDER:_DISPOSAL_FEE	BASE_FEE	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
128	129	FBAFEES	FBA_REMOVAL_ORDER:_DISPOSAL_FEE	TAX_ON_FEE	txn_ref+FBA_DISPOSAL_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
129	130	FBAFEES	FBA_INVENTORY_STORAGE_FEE	BASE_FEE	FBA_INVENTORY_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
130	131	FBAFEES	FBA_INVENTORY_STORAGE_FEE	TAX_ON_FEE	FBA_INVENTORY_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
131	132	FBAFEES	FBA_REMOVAL_ORDER:_RETURN_FEE	BASE_FEE	txn_ref+FBA_RETURN_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
132	133	FBAFEES	FBA_REMOVAL_ORDER:_RETURN_FEE	TAX_ON_FEE	txn_ref+FBA_RETURN_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
133	134	FBAFEES	FBA_LONG_TERM_STORAGE_FEE	BASE_FEE	FBA_INVENTORY_FEE_FBA_LONG-TERM_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
134	135	FBAFEES	FBA_LONG_TERM_STORAGE_FEE	TAX_ON_FEE	FBA_INVENTORY_FEE_FBA_LONG-TERM_STORAGE_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
135	136	FBAFEES	FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE	BASE_FEE	FBA_INVENTORY_FEE_FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
136	137	FBAFEES	FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE	TAX_ON_FEE	FBA_INVENTORY_FEE_FBA_AMAZON-PARTNERED_CARRIER_SHIPMENT_FEE+settlement_id+date	expenses_fba_fees	expenses_fba_fees	2026-09-16 17:17:29.64661+00
3	4	REFUND	ITEMPRICE	TAX	txn_ref+sku+date	total_refund_expense_or_sales_amt	refunded_expenses	2026-09-16 17:17:29.64661+00
137	138	OTHER-TRANSACTION	OTHER-TRANSACTION	PROMOTION_ADJUSTMENT	ADJUSTMENT_OTHER+settlement_id+date	total_adjustment_other_buyer_recharge_amt	total_adjustment_other_buyer_recharge_amt	2026-09-16 17:17:29.64661+00
123	124	OTHER-TRANSACTION	OTHER-TRANSACTION	TRANSFER_OF_FUNDS_UNSUCCESSFUL:_WE_COULD_NOT_TRANSFER_FUNDS_TO_YOUR_BANK_ACCOUNT_BECAUSE_THE_ACCOUNT_INFORMATION_ON_FILE_IS_INVALID._PLEASE_UPDATE_YOUR_BANK_ACCOUNT_INFORMATION.	TRANSFER_OF_FUNDS_UNSUCCESSFUL+settlement_id+date			2026-09-16 17:17:29.64661+00
\.


--
-- Name: payment_mapping_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payment_mapping_configs_id_seq', 149, true);


--
-- Name: settlement_mapping_configs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.settlement_mapping_configs_id_seq', 137, true);


--
-- PostgreSQL database dump complete
--

\unrestrict mGXkhrAuuCfy4qhXtSRLmswzr2DYmUdKOCCjak41it2Ovj2nHwk94XTwh9Jp2Cx

