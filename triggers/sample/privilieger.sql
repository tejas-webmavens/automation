DEF:sh6_app
DENY UPDATE {
	orders_details:alloted_qty,style_name,color_name,size_name,invoice_created,invoiced_qty,invoice_created_by,dropship_count
	styles_stock_adj:*
	styles_stock:*
	po:arrival_date
	po_detail:reserved,sent_in_stock,received,style_name,color_name,size_name,available_to_sell
	po_received_allotment:*
	invoice_details:style_name,color_name,size_name,order_details_id
	styles_cs:style_name,color_name,size_name,reserved_qty
	orders:grand_total
	m_store:store_balance,store_credits
}
DENY DELETE {
	po_received_allotment:*
}

