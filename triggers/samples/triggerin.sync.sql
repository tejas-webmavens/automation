set innodb_lock_wait_timeout = 220;
UPDATE styles_cs SET style_name = IFNULL((SELECT name FROM styles WHERE id=style_id),''),
					color_name = IFNULL((SELECT color_name FROM m_color WHERE id=color_id),''),
					size_name = IFNULL((SELECT size_name FROM m_size WHERE id=size_id),'');

UPDATE orders_details SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=style_cs_id)),''),
					color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=style_cs_id)),''),
					size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=style_cs_id)),'');

UPDATE invoice_details SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=style_cs_id)),''),
					color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=style_cs_id)),''),
					size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=style_cs_id)),'');
					
UPDATE po_detail SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=style_cs_id)),''),
					color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=style_cs_id)),''),
					size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=style_cs_id)),'');
					
UPDATE orders_request SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=styles_cs_id)),''),
					color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=styles_cs_id)),''),
					size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=styles_cs_id)),'');
					
UPDATE packingslip_details SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=(SELECT style_cs_id FROM po_detail WHERE id=po_detail_id))),''),
					color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=(SELECT style_cs_id FROM po_detail WHERE id=po_detail_id))),''),
					size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=(SELECT style_cs_id FROM po_detail WHERE id=po_detail_id))),'');

UPDATE m_store_customerlogin_orderdetail SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=style_cs_id)),''),
					color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=style_cs_id)),''),
					size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=style_cs_id)),'');

UPDATE orders SET grand_total = IFNULL((SELECT SUM(qty*sell_price) FROM orders_details WHERE order_id=orders.id),0);

UPDATE orders_details SET dropship_count=(SELECT COUNT(*) FROM orders_details_dropships WHERE order_detail_id=orders_details.id);

UPDATE po SET yet_to_ship=((SELECT SUM(qty) FROM po_detail WHERE po_id=po.id)-(SELECT SUM(qty) FROM packingslip_details WHERE (SELECT po_id FROM po_detail WHERE id=po_detail_id)=po.id AND (SELECT tracking_number FROM packingslip WHERE id=packingslip_id)<>''));

UPDATE po SET confirm=1 WHERE po.status =7 OR po.status=6;


UPDATE orders_details SET po_id=(SELECT po_id FROM po_detail WHERE id=po_detail_id);

UPDATE orders_details SET invoice_created=IF(invoiced_qty>0,1,0);

UPDATE orders_details SET invoiced_qty=(SELECT SUM(invoiced_qty*IF(invoice_sell_price>0,1,-1)) FROM invoice_details WHERE order_details_id=orders_details.id),invoice_created_by=(SELECT GROUP_CONCAT(audit_created_by SEPARATOR ',') FROM invoice_details WHERE order_details_id=orders_details.id);



UPDATE po_detail SET available_to_sell=((total_coming+received)-(reserved+sent_in_stock));



UPDATE invoice SET grand_total_cancel=IFNULL((SELECT SUM(ABS(payment_amount)*IF(payment_type<=5,1,-1)) FROM invoice_payment WHERE invoice_id=invoice.id),0)-IFNULL((SELECT SUM(amount) FROM store_payments WHERE invoice_id=invoice.id AND payment_method_id=8),0);

UPDATE invoice SET grand_total_cancel=grand_total_cancel+IFNULL((SELECT SUM(ABS(amount)) FROM payments_log WHERE invoice_id=invoice.id),0);


UPDATE invoice SET net_total=(SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*((discount/100)),discount))) FROM invoice_details WHERE invoice_id=invoice.id);

UPDATE invoice SET grand_total = IF(overall_discount_type=0, net_total * (1-(overall_discount/100)), net_total-overall_discount);


UPDATE invoice SET grand_total=IFNULL(drop_ship_fee,0)+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+grand_total;

UPDATE styles_cs SET reserved_qty = styleReservedQty(id);

