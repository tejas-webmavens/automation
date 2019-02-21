// OLD QUERIES // 

2014-10-28 23:15:12
UPDATE styles SET total_coming=(SELECT SUM(available_to_sell) FROM po_detail WHERE (SELECT style_id FROM styles_cs WHERE id=style_cs_id)=styles.id);


UPDATE styles SET total_stock=(SELECT SUM(qty_in_stock) FROM styles_stock WHERE (SELECT style_id FROM styles_cs WHERE id=styles_cs_id)=styles.id);



UPDATE factory_invoice SET locked=1 WHERE (SELECT tracking_number FROM packingslip WHERE id =factory_invoice.packinglist_id);

UPDATE po SET yet_to_ship=((SELECT SUM(qty) FROM po_detail WHERE po_id=po.id)-(SELECT SUM(qty) FROM packingslip_details WHERE (SELECT po_id FROM po_detail WHERE id=po_detail_id)=po.id AND (SELECT tracking_number FROM packingslip WHERE id=packingslip_id)<>''));

UPDATE po SET confirm=1 WHERE po.status =7 OR po.status=6;

UPDATE po_detail SET available_to_sell=((total_coming+received)-(reserved+sent_in_stock));

UPDATE invoice SET grand_total_cancel=IFNULL((SELECT SUM(ABS(amount)) FROM payments_log WHERE invoice_id=invoice.id),0);

UPDATE invoice SET grand_total_cancel=IFNULL((SELECT SUM(ABS(payment_amount)*IF(payment_type<=5,1,-1)) FROM invoice_payment WHERE invoice_id=invoice.id),0);

UPDATE orders_details SET invoiced_qty=(SELECT SUM(invoiced_qty) FROM invoice_details WHERE order_details_id=orders_details.id),invoice_created_by=(SELECT GROUP_CONCAT(audit_created_by SEPARATOR ',') FROM invoice_details WHERE order_details_id=orders_details.id);

UPDATE orders_details SET po_id=(SELECT po_id FROM po_detail WHERE id=po_detail_id);

UPDATE orders_details SET invoice_created=IF(invoiced_qty>0,1,0);

UPDATE invoice SET grand_total=IFNULL(drop_ship_fee,0)+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+(SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*((discount/100)),discount))) FROM invoice_details WHERE invoice_id=invoice.id);

UPDATE styles_cs SET reserved_qty = styleReservedQty(id);

UPDATE orders SET grand_total = IFNULL((SELECT SUM(qty*sell_price) FROM orders_details WHERE order_id=orders.id),0);

UPDATE orders_details SET dropship_count=(SELECT COUNT(*) FROM orders_details_dropships WHERE order_detail_id=orders_details.id);

UPDATE m_store SET store_balance=(SELECT SUM(grand_total) FROM invoice WHERE store_id=m_store.id)+(SELECT SUM(amount) FROM payments_log WHERE store_id=m_store.id);

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

UPDATE m_store_address SET last_qty_ordered = IFNULL((SELECT SUM(qty) FROM orders_details LEFT JOIN orders ON orders.id=orders_details.order_id WHERE orders_details.audit_created_date > DATE_SUB(NOW(), INTERVAL 12 MONTH) AND store_address_id=m_store_address.m_address_id),0);

update `styles_image_manager` set watermark_processed=1 ;

INSERT INTO `mm_store_users_permissions` (`id`, `name`, `url`, `audit_created_by`, `audit_updated_by`, `audit_created_date`, `audit_updated_date`, `audit_ip`) VALUES (NULL, 'Web Seal', '/webseal/index', NULL, NULL, NOW(), NOW(), NULL) ;

UPDATE `mm_store_users_permissions` SET `url` = '/invoice/index' WHERE `mm_store_users_permissions`.`id` =4 ;

UPDATE `mm_store_users_permissions` SET `name` = 'Home' WHERE `mm_store_users_permissions`.`id` =2 ;

DELETE FROM `mm_store_users_permissions` WHERE `mm_store_users_permissions`.`id` = 6 ;

DELETE FROM `mm_store_users_permissions` WHERE `mm_store_users_permissions`.`id` = 9 ;
 
INSERT INTO `mm_store_users_permissions` (`id`, `name`, `url`, `audit_created_by`, `audit_updated_by`, `audit_created_date`, `audit_updated_date`, `audit_ip`) VALUES (NULL, 'Help', '/homepage/index', NULL, NULL, NOW(), NOW(), NULL) ;
 
UPDATE `mm_country` SET `dropship_available` = '1' WHERE `mm_country`.`id` =1;

