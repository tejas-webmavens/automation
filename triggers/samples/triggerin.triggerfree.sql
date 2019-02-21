// OLD QUERIES // 

2015-11-30 17:49:42
UPDATE orders_details SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=style_cs_id)),''),
                                        color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=style_cs_id)),''),
                                        size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=style_cs_id)),'')  where style_name='' ;

UPDATE invoice_details SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=style_cs_id)),''),
                                        color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=style_cs_id)),''),
                                        size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=style_cs_id)),'')  where style_name=''  ;

2015-11-29 18:54:54
UPDATE po_detail SET style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=style_cs_id)),''),
                                        color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=style_cs_id)),''),
                                        size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=style_cs_id)),'')  where style_name='' ;

2015-11-18 13:49:30
UPDATE orders SET total_qty = (SELECT SUM(CAST(qty AS UNSIGNED)-CAST(LEAST(qty,returned_qty) AS UNSIGNED)) FROM orders_details WHERE order_id=orders.id)+IFNULL((SELECT SUM(qty) FROM orders_request WHERE order_id=orders.id and order_details_id=0),0);

2015-05-07 00:19:20
-php-
$all_invoices = mysqli_query($con,"SELECT SQL_CALC_FOUND_ROWS id FROM invoice WHERE store_id IN (2170)");
$total_invoices = mysqli_query($con,"SELECT FOUND_ROWS()");
$total_invoices = $total_invoices->fetch_assoc();
$total_invoices = array_shift($total_invoices);
echo "$total_invoices to do\n";
$n=0;
while($i=$all_invoices->fetch_assoc()) {
        $grand_total_cancel = mysqli_query($con,"SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_create$
                                                                UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHER$
                                                                UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE invoice_id$
        $grand_total_cancel = $grand_total_cancel->fetch_assoc();
        $grand_total_cancel = array_shift($grand_total_cancel);

        mysqli_query($con, "UPDATE invoice SET grand_total_cancel='$grand_total_cancel' WHERE id=$i[id]");

        $n++;

        if($n%10==0) echo "$n of $total_invoices\n";
}

--php--

2015-05-07 00:11:23
DELETE FROM store_payments WHERE store_id IN (2170) and year(audit_created_date)<='2013';

DELETE FROM invoice_payment WHERE (select store_id from invoice where id=invoice_id) IN (2170)  and year(audit_created_date)<='2013';

update invoice_details set discount=100 where (select store_id from invoice where id=invoice_id) in (2170)  and year(audit_created_date)<='2013';

update invoice set other_charges = 0 where store_id = 2170  and year(audit_created_date)<='2013';

2015-05-06 23:48:40
update `invoice` set overall_discount=0 WHERE overall_discount='100' and overall_discount_type=0 and `store_id` = '2103' and year(audit_created_date)=2013 ;

DELETE FROM store_payments WHERE store_id IN (1375,2105,2537,2464,1990,1991,1485,1764,1486);

DELETE FROM invoice_payment WHERE (select store_id from invoice where id=invoice_id) IN (1375,2105,2537,2464,1990,1991,1485,1764,1486);

update invoice_details set discount=100 where (select store_id from invoice where id=invoice_id) in (1375,2105,2537,2464,1990,1991,1485,1764,1486);

/* script to fix grand_total_cancel */
-php-
$all_invoices = mysqli_query($con,"SELECT SQL_CALC_FOUND_ROWS id FROM invoice WHERE store_id IN (1375,2105,2537,2464,1990,1991,1485,1764,1486)");
$total_invoices = mysqli_query($con,"SELECT FOUND_ROWS()");
$total_invoices = $total_invoices->fetch_assoc();
$total_invoices = array_shift($total_invoices);
echo "$total_invoices to do\n";
$n=0;
while($i=$all_invoices->fetch_assoc()) {
	$grand_total_cancel = mysqli_query($con,"SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM payments_log WHERE invoice_id=$i[id])
								UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHERE invoice_id=$i[id])
								UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE invoice_id=$i[id] AND payment_method_id>5)) AS tbl");
	$grand_total_cancel = $grand_total_cancel->fetch_assoc();
	$grand_total_cancel = array_shift($grand_total_cancel);
	
	mysqli_query($con, "UPDATE invoice SET grand_total_cancel='$grand_total_cancel' WHERE id=$i[id]");
	
	$n++;
	
	if($n%10==0) echo "$n of $total_invoices\n";
}

--php--
/* script to fix grand_total_cancel - end */

UPDATE invoice SET invoice_status=1 WHERE IFNULL(grand_total_cancel,0)=0;

UPDATE invoice SET invoice_status=2 WHERE IFNULL(grand_total_cancel,0)>=IFNULL(grand_total,0);

UPDATE invoice SET invoice_status=3 WHERE IFNULL(grand_total_cancel,0)>0 AND IFNULL(grand_total_cancel,0) < IFNULL(grand_total,0);








/* script to fix grand_total_cancel */
-php-
$all_invoices = mysqli_query($con,"SELECT SQL_CALC_FOUND_ROWS id FROM invoice WHERE ABS(grand_total)<>ABS(grand_total_cancel)");
$total_invoices = mysqli_query($con,"SELECT FOUND_ROWS()");
$total_invoices = $total_invoices->fetch_assoc();
$total_invoices = array_shift($total_invoices);
echo "$total_invoices to do\n";
$n=0;
while($i=$all_invoices->fetch_assoc()) {
	$grand_total_cancel = mysqli_query($con,"SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM payments_log WHERE invoice_id=$i[id])
								UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHERE invoice_id=$i[id])
								UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE invoice_id=$i[id] AND payment_method_id>5)) AS tbl");
	$grand_total_cancel = $grand_total_cancel->fetch_assoc();
	$grand_total_cancel = array_shift($grand_total_cancel);
	
	mysqli_query($con, "UPDATE invoice SET grand_total_cancel='$grand_total_cancel' WHERE id=$i[id]");
	
	$n++;
	
	if($n%10==0) echo "$n of $total_invoices\n";
}

--php--


/* script to fix grand_total_cancel - end */
2015-04-30 16:17:28
UPDATE styles_cs SET reserved_qty = styleReservedQty(id);


/* run for bug #5450 */
UPDATE packingslip SET audit_created_date=audit_updated_date WHERE audit_created_date IS NULL;


/* run for bug 5452 */
UPDATE po SET `status`=7 WHERE (SELECT SUM(qty) FROM po_detail WHERE po_id=po.id) <= (SELECT SUM(received) FROM po_detail WHERE po_id=po.id);

/* run for bug #5465 */
UPDATE orders_details SET invoiced_qty=(SELECT SUM(invoiced_qty*IF(invoice_sell_price>=0,1,-1)) FROM invoice_details WHERE order_details_id=orders_details.id),invoice_created_by=(SELECT GROUP_CONCAT(audit_created_by SEPARATOR ',') FROM invoice_details WHERE order_details_id=orders_details.id);

2015-03-05 14:36:04
DELETE FROM rush_requested_detail WHERE rush_requested_detail.rush_request_id IN (SELECT id FROM rush_request WHERE cancelled>0);

/* to run for bug #5381 */
UPDATE invoice SET total_qty = (SELECT SUM(invoiced_qty) FROM invoice_details WHERE invoice_id=invoice.id);

UPDATE orders SET total_qty = (SELECT SUM(CAST(qty AS UNSIGNED)-CAST(LEAST(qty,returned_qty) AS UNSIGNED)) FROM orders_details WHERE order_id=orders.id)+(SELECT SUM(qty) FROM orders_request WHERE order_id=orders.id);
/* //// */




/* bug 5381 */
UPDATE orders SET grand_total = IFNULL((SELECT SUM(qty*(IF(discount_type=0,sell_price*(1-(discount/100)),sell_price-discount))) FROM orders_details WHERE order_id=orders.id),0);
/* */


2015-02-11 17:33:49
/* bug 5375 */
UPDATE packingslip SET total_qty=(SELECT SUM(qty) FROM packingslip_details WHERE packingslip_id=packingslip.id), total_received_qty=(SELECT SUM(LEAST(qty,received_qty)) FROM packingslip_details WHERE packingslip_id=packingslip.id);
/* // bug 5375 */

2015-02-10 15:43:10
UPDATE main_search SET store_id = (SELECT store_id FROM orders WHERE id = action_id)  WHERE search_type='order';

UPDATE main_search SET store_id =action_id WHERE search_type IN('profile','profile_name');

UPDATE main_search SET store_id = (SELECT store_id FROM invoice WHERE id = action_id)  WHERE search_type='invoice';

2015-02-09 11:29:55
/* yet to run BUG #5358 */

UPDATE rush_request SET cancelled=1, cancelled_reason='Auto un-rushed because item was invoiced', cancelled_comments='Auto un-rushed because item was invoiced' WHERE (SELECT COUNT(*) FROM invoice_details WHERE order_details_id=order_detail_id)>0;

/* // yet to run */

2015-01-29 14:56:39
UPDATE po_detail SET reserved=(SELECT SUM(qty-IFNULL(alloted_qty,0)) as reserved FROM orders_details WHERE po_detail_id = po_detail.id);




-php-
$__statuses = array("invoice" => 5,
					"poreceived" => 6,
					"unshipped" => 5,
					"packing" => 10,
					"shipped" => 2,
					"deletedinvoice" => 6,
					);
					
$_res = mysqli_query($con,"SELECT * FROM `orders_details` WHERE status_id = 11 and length(status_history) > 56 ");
while($_r = $_res->fetch_assoc()) {
	$_sthistory = explode("###",$_r["status_history"]);
	array_shift($_sthistory);
	list($nnn,$nnnn,$_old_status) = explode(",",$_sthistory[0]);
	
	$ns = $__statuses[$_old_status];
	if($ns>0) {
		mysqli_query($con,"UPDATE orders_details SET status_id=$ns WHERE id=$_r[id]");
	} else {
		echo "status $_old_status failed\n";
	}
}
--php--

-php-
$_nulls = mysqli_query($con,"SELECT id FROM orders_details WHERE qty IS NULL");
while($_n = $_nulls->fetch_assoc()) {
	echo "> testing $_n[id]...";
	$_Q = "SELECT old_data FROM sw_sh6_logs.log_sql 
				WHERE record_id=(
									SELECT record_id FROM sw_sh6_logs.log_sql 
										WHERE table_name='m_store_customerlogin_orderdetail' 
											AND old_data=".$_n[id]." 
											AND field_name='order_detail_id' 
											AND `operation`='delete'
								) 
						AND table_name='m_store_customerlogin_orderdetail' 
						AND field_name='qty'
						AND `operation`='delete'";
	
	$_res_new_qty = mysqli_query($con,$_Q);
	$_new_qty = $_res_new_qty->fetch_array();
	
	$_new_qty = @array_shift($_new_qty);
	if($_new_qty>0) {
		echo "$_new_qty\n";
		mysqli_query($con,"UPDATE orders_details SET qty='$_new_qty' WHERE id=$_n[id]");
	} else {
		echo "not found, setting to 1\n";
		mysqli_query($con,"UPDATE orders_details SET qty=1, notes=CONCAT(notes,' (system: qty may be wrong, pl verify with customer)') WHERE id=$_n[id]");
	}

}

--php--

update po_detail set available_to_sell_tmp = available_to_sell;

UPDATE po_detail SET available_to_sell=(qty - GREATEST(reserved,received));


2015-01-08 13:29:13
UPDATE orders_details SET status_id=IF((SELECT tracking_number FROM invoice WHERE tracking_number<>'' AND id IN (SELECT invoice_id FROM invoice_details WHERE order_details_id=orders_details.id))<>'',2,status_id) WHERE audit_created_date>'2015-01-01'

2015-01-07 12:19:52


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


UPDATE orders SET comments_private = (SELECT GROUP_CONCAT(notes SEPARATOR '\n') FROM notes WHERE record_id=orders.id AND notes_source='order' AND private=0);

UPDATE orders SET comments = (SELECT GROUP_CONCAT(notes SEPARATOR '\n') FROM notes WHERE record_id=orders.id AND notes_source='order' AND private=1);


2014-12-18 18:20:54
UPDATE invoice SET net_total=(SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*((discount/100)),discount))) FROM invoice_details WHERE invoice_id=invoice.id);

UPDATE invoice SET grand_total = IF(overall_discount_type=0, net_total * (1-(overall_discount/100)), net_total-overall_discount);


UPDATE invoice SET grand_total=IFNULL(drop_ship_fee,0)+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+grand_total;



2014-12-18 12:02:04


2014-12-16 19:58:35
UPDATE styles_cs SET reserved_qty = styleReservedQty(id);

2014-12-10 17:47:25
UPDATE invoice SET grand_total=(SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*((discount/100)),discount))) FROM invoice_details WHERE invoice_id=invoice.id);

UPDATE invoice SET grand_total = IF(overall_discount_type=0, grand_total * (1-(overall_discount/100)), grand_total-overall_discount);


UPDATE invoice SET grand_total=IFNULL(drop_ship_fee,0)+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+grand_total;



UPDATE styles SET total_coming=(SELECT SUM(available_to_sell) FROM po_detail WHERE (SELECT style_id FROM styles_cs WHERE id=style_cs_id)=styles.id);


UPDATE styles SET total_stock=(SELECT SUM(qty_in_stock) FROM styles_stock WHERE (SELECT style_id FROM styles_cs WHERE id=styles_cs_id)=styles.id);



UPDATE factory_invoice SET locked=1 WHERE (SELECT tracking_number FROM packingslip WHERE id =factory_invoice.packinglist_id);

UPDATE po SET yet_to_ship=((SELECT SUM(qty) FROM po_detail WHERE po_id=po.id)-(SELECT SUM(qty) FROM packingslip_details WHERE (SELECT po_id FROM po_detail WHERE id=po_detail_id)=po.id AND (SELECT tracking_number FROM packingslip WHERE id=packingslip_id)<>''));

UPDATE po SET confirm=1 WHERE po.status =7 OR po.status=6;

UPDATE po_detail SET available_to_sell=((total_coming+received)-(reserved+sent_in_stock));



UPDATE orders_details SET po_id=(SELECT po_id FROM po_detail WHERE id=po_detail_id);

UPDATE orders_details SET invoice_created=IF(invoiced_qty>0,1,0);

UPDATE invoice SET grand_total=IFNULL(drop_ship_fee,0)+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+(SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*((discount/100)),discount))) FROM invoice_details WHERE invoice_id=invoice.id);

UPDATE styles_cs SET reserved_qty = styleReservedQty(id);

UPDATE orders_details SET dropship_count=(SELECT COUNT(*) FROM orders_details_dropships WHERE order_detail_id=orders_details.id);

UPDATE m_store SET store_balance=(SELECT SUM(grand_total) FROM invoice WHERE store_id=m_store.id)+(SELECT SUM(amount) FROM payments_log WHERE store_id=m_store.id);


UPDATE m_store_address SET last_qty_ordered = IFNULL((SELECT SUM(qty) FROM orders_details LEFT JOIN orders ON orders.id=orders_details.order_id WHERE orders_details.audit_created_date > DATE_SUB(NOW(), INTERVAL 12 MONTH) AND store_address_id=m_store_address.m_address_id),0);

update `styles_image_manager` set watermark_processed=1 ;

INSERT INTO `mm_store_users_permissions` (`id`, `name`, `url`, `audit_created_by`, `audit_updated_by`, `audit_created_date`, `audit_updated_date`, `audit_ip`) VALUES (NULL, 'Web Seal', '/webseal/index', NULL, NULL, NOW(), NOW(), NULL) ;

UPDATE `mm_store_users_permissions` SET `url` = '/invoice/index' WHERE `mm_store_users_permissions`.`id` =4 ;

UPDATE `mm_store_users_permissions` SET `name` = 'Home' WHERE `mm_store_users_permissions`.`id` =2 ;

DELETE FROM `mm_store_users_permissions` WHERE `mm_store_users_permissions`.`id` = 6 ;

DELETE FROM `mm_store_users_permissions` WHERE `mm_store_users_permissions`.`id` = 9 ;
 
INSERT INTO `mm_store_users_permissions` (`id`, `name`, `url`, `audit_created_by`, `audit_updated_by`, `audit_created_date`, `audit_updated_date`, `audit_ip`) VALUES (NULL, 'Help', '/homepage/index', NULL, NULL, NOW(), NOW(), NULL) ;
 
UPDATE `mm_country` SET `dropship_available` = '1' WHERE `mm_country`.`id` =1;


UPDATE invoice SET grand_total=IFNULL(drop_ship_fee,0)+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+(SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*((discount/100)),discount))) FROM invoice_details WHERE invoice_id=invoice.id);




UPDATE invoice SET grand_total=(SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*(1-(discount/100)),discount))) FROM invoice_details WHERE invoice_id=invoice.id);



2014-11-04 15:15:05
UPDATE po SET yet_to_ship=((SELECT SUM(qty) FROM po_detail WHERE po_id=po.id)-(SELECT SUM(qty) FROM packingslip_details WHERE (SELECT po_id FROM po_detail WHERE id=po_detail_id)=po.id AND (SELECT tracking_number FROM packingslip WHERE id=packingslip_id)<>''));

2014-10-30 11:15:43
UPDATE po_detail SET available_to_sell=((total_coming+received)-(reserved+sent_in_stock));




UPDATE invoice SET grand_total=(SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*(1-(discount/100)),discount))) FROM invoice_details WHERE invoice_id=invoice.id);