DEF:orders
BEFORE UPDATE {
	/*audit_sql*/
	
	SET @total_for_order = (SELECT SUM(qty*(IF(discount_type=0,sell_price*(1-(discount/100)),sell_price-discount))) FROM orders_details WHERE order_id=OLD.id);
    SET NEW.grand_total = IFNULL(@total_for_order,0);
    
    IF IFNULL(NEW.order_start_date,'0000-00-00')>'0000-00-00' THEN
		IF OLD.order_start_date<>NEW.order_start_date THEN
			IF NEW.order_start_date < DATE(CURRENT_TIMESTAMP()) THEN
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Order start date cannot be earlier than current date";
			END IF;
		END IF;
	END IF;
    
    IF IFNULL(NEW.order_end_date,'0000-00-00')>'0000-00-00' THEN
		IF IFNULL(NEW.order_start_date,'')<>'' AND IFNULL(NEW.order_end_date,'')<>'' THEN 
			IF NEW.order_end_date<NEW.order_start_date THEN
				SET @msg=CONCAT("1 Order end date cannot be earlier than order start date ",NEW.id, " ",NEW.order_end_date," ",NEW.order_start_date);
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
			END IF;
		ELSE
			IF OLD.order_start_date THEN
				IF NEW.order_end_date<OLD.order_start_date THEN
					SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "2 Order end date cannot be earlier than order start date";
				END IF;
			END IF;
		END IF;
    END IF;
}
AFTER UPDATE {
	IF IFNULL(OLD.store_address_id,0)<>IFNULL(NEW.store_address_id,0) THEN
		SET @store_address_id = OLD.store_address_id;
		IF @store_address_id>0 THEN
			SET @date_orders_start = DATE_SUB(NOW(), INTERVAL 12 MONTH);
			SET @ordered_last_12_month = IFNULL((SELECT SUM(qty) FROM orders_details LEFT JOIN orders o ON o.id=orders_details.order_id WHERE orders_details.audit_created_date > @date_orders_start AND store_address_id=@store_address_id),0);
			UPDATE m_store_address SET last_qty_ordered = @ordered_last_12_month WHERE store_id=(SELECT store_id FROM orders WHERE id =NEW.id);
		END IF;
		
		SET @store_address_id = NEW.store_address_id;
		IF @store_address_id>0 THEN
			SET @date_orders_start = DATE_SUB(NOW(), INTERVAL 12 MONTH);
			SET @ordered_last_12_month = IFNULL((SELECT SUM(qty) FROM orders_details LEFT JOIN orders o ON o.id=orders_details.order_id WHERE orders_details.audit_created_date > @date_orders_start AND store_address_id=@store_address_id),0);
			UPDATE m_store_address SET last_qty_ordered = @ordered_last_12_month WHERE store_id=(SELECT store_id FROM orders WHERE id =NEW.id);
		END IF;
	END IF;
}
BEFORE INSERT {
/*audit_sql*/
	IF IFNULL(NEW.order_start_date,'0000-00-00')>'0000-00-00' THEN
		IF NEW.order_start_date < DATE(CURRENT_TIMESTAMP()) THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Order start date cannot be earlier than current date";
		END IF;
		
		IF IFNULL(NEW.order_start_date,'0000-00-00')>'0000-00-00' AND IFNULL(NEW.order_end_date,'0000-00-00')>'0000-00-00' THEN
			IF NEW.order_end_date<NEW.order_start_date THEN
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "3 Order end date cannot be earlier than order start date";
			END IF;
		END IF;
    END IF;
    
    IF IFNULL(NEW.order_end_date,'0000-00-00')>'0000-00-00' THEN
		IF NEW.order_end_date<DATE(CURRENT_TIMESTAMP()) THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Order end date cannot be earlier than current date";
		END IF;
    END IF;
}
AFTER INSERT {
	/* watches log for orders placed */
	INSERT INTO watches_log SET `store_id`=NEW.store_id, `order_id`=NEW.id, `m_watches_id`=2,audit_created_by=CONCAT('orders trigger');
	
	INSERT INTO main_search SET action_id=NEW.id, search_value=NEW.id, search_type="order",store_id=(SELECT store_id FROM orders WHERE id=NEW.id) ,audit_created_by=CONCAT('orders trigger');
}
AFTER DELETE {
	DELETE FROM main_search WHERE action_id=OLD.id;
}
DEF:invoice_details
BEFORE INSERT {
	/*audit_sql*/
	
	IF NEW.invoiced_qty < 1 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Invoiced qty cannot be zero";
	END IF;
	
	SET @invoiced_qty = IFNULL((SELECT SUM(invoiced_qty) FROM invoice_details WHERE order_details_id=NEW.order_details_id),0);
	
	SET @order_alloted = (SELECT alloted_qty FROM orders_details WHERE id=NEW.order_details_id);

	IF NEW.invoiced_qty+@invoiced_qty > @order_alloted THEN
		SET @msg = CONCAT('Invoice qty(',NEW.invoiced_qty,') plus previously invoiced(',@invoiced_qty,'), is more than order qty(',@order_alloted,') ');
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;

	SET @sell_price = (SELECT sell_price FROM orders_details WHERE id=NEW.order_details_id);
	
	IF NEW.invoice_sell_price<>@sell_price THEN
		SET @msg = CONCAT('Invoice sell price ',NEW.invoice_sell_price,' is different than order sell price ',@sell_price);
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;
	
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	
}
AFTER INSERT {
	UPDATE styles_cs SET reserved_qty = styleReservedQty(NEW.style_cs_id) WHERE id=NEW.style_cs_id;
	
	SET @total_for_invoice = IFNULL((SELECT SUM(invoiced_qty*(invoice_sell_price-(IF(discount_type=0,(invoice_sell_price)*((discount/100)),discount)))) FROM invoice_details WHERE invoice_id=NEW.invoice_id),0);
	UPDATE invoice SET grand_total=IFNULL(IF(store_address_id>0,0,IFNULL(drop_ship_fee,0))+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+IF(overall_discount_type=0, @total_for_invoice * (1-(overall_discount/100)), @total_for_invoice-overall_discount),0), net_total=IFNULL(@total_for_invoice,0) WHERE id=NEW.invoice_id;
	
	SET @invoiced_qty = (SELECT SUM(invoiced_qty*IF(invoice_sell_price>=0,1,-1)) FROM invoice_details WHERE order_details_id=NEW.order_details_id);
	
	SET @users_that_invoiced = (SELECT GROUP_CONCAT(audit_created_by SEPARATOR ',') FROM invoice_details WHERE order_details_id=NEW.order_details_id);
	
	SET @order_detail_qty = IFNULL((SELECT qty FROM orders_details WHERE id=NEW.order_details_id),0);
	
	IF ((@order_detail_qty = @invoiced_qty) ) THEN
		/* order detail status = invoiced */
		UPDATE orders_details SET invoice_created=1,status_id=5, status_history=CONCAT('invoice',',',NEW.invoice_id,',',@app_username),invoiced_qty=@invoiced_qty,invoice_created_by=@users_that_invoiced WHERE id=NEW.order_details_id;
	ELSE
		/* order detail status = part invoiced */
		UPDATE orders_details SET invoice_created=1,status_id=8, status_history=CONCAT('invoice',',',NEW.invoice_id,',',@app_username), invoiced_qty=@invoiced_qty,invoice_created_by=@users_that_invoiced WHERE id=NEW.order_details_id;
	END IF; 
	
	SET @po_detail_id=(SELECT po_detail_id FROM orders_details WHERE id=NEW.order_details_id);
	IF @po_detail_id=0 THEN
		SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=NEW.style_cs_id);
		SET @orderid=(SELECT order_id FROM orders_details WHERE id=NEW.order_details_id);
		INSERT INTO styles_stock_adj SET instock_styles_cs_id=@stock_cs_id, qty=(0-CAST(NEW.invoiced_qty AS SIGNED)), reason=CONCAT('Order #',@orderid,' added item'), audit_created_by=CONCAT('invoice_details trigger'), audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
	END IF;
	
	UPDATE rush_request SET cancelled=1, cancelled_reason='Auto un-rushed because item was invoiced', cancelled_comments='Auto un-rushed because item was invoiced' WHERE order_detail_id=NEW.order_details_id;
	
	/* status invoiced*/
	
	UPDATE invoice SET total_qty = IFNULL((SELECT SUM(invoiced_qty) FROM invoice_details WHERE invoice_id=NEW.invoice_id),0) WHERE id=NEW.invoice_id;
}
BEFORE DELETE {
	/*audit_sql*/
	
	
	/*deleted_tables_sql*/
}
BEFORE UPDATE {
	/*audit_sql*/
	
	IF NEW.invoiced_qty=0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoiced qty cannot be zero';
	END IF;
	
	SET @invoiced_qty = IFNULL((SELECT SUM(invoiced_qty) FROM invoice_details WHERE id<>OLD.id AND order_details_id=NEW.order_details_id),0);
	SET @order_qty = IFNULL((SELECT qty FROM orders_details WHERE id=NEW.order_details_id),0);

	IF NEW.invoiced_qty>OLD.invoiced_qty THEN
		IF (NEW.invoiced_qty+@invoiced_qty) > @order_qty THEN
			SET @msg = CONCAT('Invoice qty(',NEW.invoiced_qty,') plus previously invoiced(',@invoiced_qty,'), is more than order qty(',@order_qty,') ');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
	
	IF OLD.style_cs_id<>NEW.style_cs_id THEN
		SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
		SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
		SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	END IF;
	
	SET @po_detail_id=(SELECT po_detail_id FROM orders_details WHERE id=OLD.order_details_id);
	IF @po_detail_id=0 THEN
		SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=NEW.style_cs_id);
		SET @orderid=(SELECT order_id FROM orders_details WHERE id=NEW.order_details_id);
		INSERT INTO styles_stock_adj SET instock_styles_cs_id=@stock_cs_id, qty=(OLD.invoiced_qty-NEW.invoiced_qty), reason=CONCAT('Order #',@orderid,' updated qty'), audit_created_by=CONCAT('invoice_details trigger'), audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
	END IF;
	/*IF NEW.tracking_number <> OLD.tracking_number THEN
		SET NEW.ship_date = NOW();
	END IF;*/
	
	IF @let_user_set_invoice_price IS NULL OR @let_user_set_invoice_price=0 THEN
		IF OLD.invoice_sell_price<>IFNULL(NEW.invoice_sell_price,OLD.invoice_sell_price) THEN
			SET @msg = CONCAT('You cannot set the invoice price. Sorry.');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
}
AFTER UPDATE {
	SET @total_for_invoice = IFNULL((SELECT SUM(invoiced_qty*(invoice_sell_price-(IF(discount_type=0,(invoice_sell_price)*((discount/100)),discount)))) FROM invoice_details WHERE invoice_id=NEW.invoice_id),0);
	UPDATE invoice SET grand_total=IFNULL(IF(store_address_id>0,0,IFNULL(drop_ship_fee,0))+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+IF(overall_discount_type=0, @total_for_invoice * (1-(overall_discount/100)), @total_for_invoice-overall_discount),0), net_total=IFNULL(@total_for_invoice,0) WHERE id=NEW.invoice_id;
	
	UPDATE styles_cs SET reserved_qty = styleReservedQty(NEW.style_cs_id) WHERE id=NEW.style_cs_id;
	
	
	IF IFNULL(NEW.invoiced_qty,OLD.invoiced_qty)>OLD.invoiced_qty THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice qty can only be reduced';
	ELSE
		SET @invoiced_qty = (SELECT SUM(invoiced_qty*IF(invoice_sell_price>=0,1,-1)) FROM invoice_details WHERE order_details_id=NEW.order_details_id);
		
		SET @users_that_invoiced = (SELECT GROUP_CONCAT(audit_created_by SEPARATOR ',') FROM invoice_details WHERE order_details_id=NEW.order_details_id);
		
		SET @order_detail_qty = IFNULL((SELECT qty FROM orders_details WHERE id=NEW.order_details_id),0);
		
		IF ((@order_detail_qty = @invoiced_qty) ) THEN
			/* order detail status = invoiced */
			UPDATE orders_details SET invoice_created=1,status_id=5, status_history=CONCAT('invoiceqty',',',NEW.invoice_id,',',@app_username),invoiced_qty=@invoiced_qty,invoice_created_by=@users_that_invoiced WHERE id=NEW.order_details_id;
		ELSE
			/* order detail status = part invoiced */
			UPDATE orders_details SET invoice_created=1,status_id=8, status_history=CONCAT('invoiceqty',',',NEW.invoice_id,',',@app_username), invoiced_qty=@invoiced_qty,invoice_created_by=@users_that_invoiced WHERE id=NEW.order_details_id;
		END IF; 
		
	END IF;
	
	UPDATE invoice SET total_qty = IFNULL((SELECT SUM(invoiced_qty) FROM invoice_details WHERE invoice_id=NEW.invoice_id),0) WHERE id=NEW.invoice_id;
}
AFTER DELETE {
	SET @po_detail_id=(SELECT po_detail_id FROM orders_details WHERE id=OLD.order_details_id);
	IF @po_detail_id=0 AND (@deleted_comments NOT LIKE 'Item returned ret. id #%') THEN
		SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=OLD.style_cs_id);
		SET @orderid=(SELECT order_id FROM orders_details WHERE id=OLD.order_details_id);
		INSERT INTO styles_stock_adj SET instock_styles_cs_id=@stock_cs_id, qty=(CAST(OLD.invoiced_qty AS SIGNED)), reason=CONCAT('Order #',@orderid,' removed item'), audit_created_by=CONCAT('invoice_details trigger'), audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
/*	ELSE
		IF @po_detail_id>0 THEN
			
		END IF;*/
	END IF;
	
	SET @invoiced_qty = (SELECT SUM(invoiced_qty*IF(invoice_sell_price>=0,1,-1)) FROM invoice_details WHERE order_details_id=OLD.order_details_id);
	
	SET @users_that_invoiced = (SELECT GROUP_CONCAT(audit_created_by SEPARATOR ',') FROM invoice_details WHERE order_details_id=OLD.order_details_id);
	
	IF @invoiced_qty>0 THEN
		/* order detail status = part invoiced */
		UPDATE orders_details SET invoice_created=1,status_id=8,status_history=CONCAT('deletedinvoice',',',OLD.invoice_id,',',@app_username), invoiced_qty=@invoiced_qty,invoice_created_by=@users_that_invoiced WHERE id=OLD.order_details_id;
	ELSE
		
		UPDATE orders_details SET invoice_created=0,status_id=6,status_history=CONCAT('deletedinvoice',',',OLD.invoice_id,',',@app_username), invoiced_qty=0,invoice_created_by='' WHERE id=OLD.order_details_id;
	END IF; 
	
	UPDATE styles_cs SET reserved_qty = styleReservedQty(OLD.style_cs_id) WHERE id=OLD.style_cs_id;
	
	SET @total_for_invoice = IFNULL((SELECT SUM(invoiced_qty*(invoice_sell_price-(IF(discount_type=0,(invoice_sell_price)*((discount/100)),discount)))) FROM invoice_details WHERE invoice_id=OLD.invoice_id),0);
	UPDATE invoice SET grand_total=IFNULL(IF(store_address_id>0,0,IFNULL(drop_ship_fee,0))+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+IF(overall_discount_type=0, @total_for_invoice * (1-(overall_discount/100)), @total_for_invoice-overall_discount),0), net_total=IFNULL(@total_for_invoice,0) WHERE id=OLD.invoice_id;
	
	IF IFNULL(@dont_autocredit_ondelete,0)=0 THEN
		SET @total_for_invoice = (SELECT grand_total FROM invoice WHERE id=OLD.invoice_id);
		
		/*SET @total_payments = IFNULL((SELECT SUM(ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) FROM payments_log WHERE invoice_id=OLD.invoice_id),0)+IFNULL((SELECT SUM(ABS(payment_amount)*IF(payment_type<=5,1,-1)) FROM invoice_payment WHERE invoice_id=OLD.invoice_id),0)-IFNULL((SELECT SUM(amount) FROM store_payments WHERE invoice_id=OLD.invoice_id AND payment_method_id>5),0);*/
		
		SET @total_payments = (SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM payments_log WHERE invoice_id=OLD.invoice_id)
								UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHERE invoice_id=OLD.invoice_id)
								UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE invoice_id=OLD.invoice_id AND payment_method_id>5)) AS tbl);
		
		IF @total_payments>@total_for_invoice THEN
			SET @credit = @total_for_invoice-@total_payments;
			
			SET @store_id = (SELECT store_id FROM invoice WHERE id=OLD.invoice_id);
			
			SET @credit_notes = CONCAT("Deleted item on invoice #",OLD.invoice_id);
			
			INSERT INTO payments_log SET invoice_id=OLD.invoice_id,store_id=@store_id, amount=@credit, credit_amount=ABS(@credit), payment_type=-1;
		END IF;
	END IF;
	
	UPDATE invoice SET total_qty = IFNULL((SELECT SUM(invoiced_qty) FROM invoice_details WHERE invoice_id=OLD.invoice_id),0) WHERE id=OLD.invoice_id;
}
DEF:orders_details
BEFORE UPDATE {
	/*audit_sql*/
	
/*	SET @total_alloted = (SELECT SUM(qty_alloted) FROM po_received_allotment WHERE po_detail_id=NEW.po_detail_id);
	SET @po_qty = (SELECT qty FROM po_detail WHERE id=NEW.po_detail_id);
	
	IF (@total_alloted) > @po_qty THEN
		SET @msg = CONCAT('Integrity error. PO#',(SELECT po_id FROM po_detail WHERE id=NEW.po_detail_id),' is over alloted');
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;*/
	
	
	IF IFNULL(OLD.order_id,0)<>IFNULL(NEW.order_id,0) THEN
		SET @store_discount = (SELECT store_discount_level FROM m_store WHERE id=(SELECT store_id FROM orders WHERE id=NEW.order_id));
		IF IFNULL(@store_discount,0)>0 THEN
			SET @discount = (SELECT discount_percentage FROM mm_discount_level WHERE id=@store_discount);
			SET NEW.discount = @discount;
			SET NEW.discount_type = '0';
		END IF;
	END IF;
	
	IF NEW.bridal_extra_charge<>OLD.bridal_extra_charge THEN
		SET NEW.sell_price = OLD.sell_price+(NEW.bridal_extra_charge-OLD.bridal_extra_charge);
	END IF;
		
	IF OLD.style_cs_id<>NEW.style_cs_id THEN
		SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
		SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
		SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	END IF;
	
	IF IFNULL(NEW.qty,OLD.qty)<>OLD.qty THEN 
		IF IFNULL(NEW.qty,0)>0 THEN
			IF NEW.qty < OLD.qty THEN 
				IF NEW.qty >= IFNULL((SELECT SUM(invoiced_qty*IF(invoice_sell_price<0,-1,1)) FROM invoice_details WHERE NEW.id=order_details_id),0)  THEN
					IF OLD.po_detail_id>0 THEN
						SET @alloted_qty = CAST(OLD.alloted_qty AS SIGNED);
						IF @alloted_qty>0 THEN
							IF @alloted_qty >= NEW.qty THEN
								SET NEW.alloted_qty=IFNULL(NEW.alloted_qty,0)+(CAST(NEW.qty AS SIGNED)-@alloted_qty);
							ELSE
								SET @qty = NEW.qty-IFNULL(@alloted_qty,0);
								
								SET @reserved_qty = (SELECT reserved FROM po_detail WHERE id=NEW.po_detail_id);
								IF @reserved_qty<@qty THEN
									SET @msg = CONCAT('Alloted(',IFNULL(@alloted_qty,0),')+Reserved(',IFNULL(@reserved_qty,0),') Qty is lower than Order Qty(',OLD.qty,')! Cannot continue!');
									SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
								END IF;
								
							END IF;
						END IF;
					ELSE
						SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=NEW.style_cs_id);
						SET NEW.alloted_qty = NEW.qty;
					END IF;
				ELSE
					SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New qty is lower than invoiced qty';
				END IF;
			ELSE
				IF NEW.qty > OLD.qty THEN
					SET @qty = NEW.qty - OLD.qty;
					IF IFNULL(OLD.po_detail_id,0)>0 THEN
						SET @po_qty = (SELECT qty FROM po_detail WHERE id=OLD.po_detail_id);
						SET @reserved_qty = (SELECT reserved FROM po_detail WHERE id=NEW.po_detail_id);
						SET @sent_in_stock = (SELECT sent_in_stock FROM po_detail WHERE id=NEW.po_detail_id);
						SET @received = (SELECT received FROM po_detail WHERE id=NEW.po_detail_id);
						
						IF (@po_qty-@reserved_qty-IFNULL(@sent_in_stock,0)) >= @qty THEN
							
							SET NEW.alloted_qty = IFNULL(OLD.alloted_qty,0)+@qty;
						ELSE
							SET @msg = CONCAT('Qty cannot be greater than available Qty in PO(',(IFNULL(@po_qty,0)-IFNULL(@reserved_qty,0)-IFNULL(@sent_in_stock,0)),')');
							
							SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
						END IF;
					ELSE
						SET @reserved_in_orders = (select IFNULL(sum(qty-returned_qty-invoiced_qty),0) from orders_details where po_detail_id=0 AND NEW.style_cs_id = orders_details.style_cs_id and status_id IN (6,8));
						SET @stock_qty = (SELECT qty_in_stock FROM styles_stock WHERE styles_cs_id=NEW.style_cs_id);
						IF (@stock_qty-@reserved_in_orders) >= CAST((NEW.qty - OLD.qty) AS UNSIGNED) THEN
							SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=NEW.style_cs_id);
							
							SET NEW.alloted_qty = NEW.qty;
						ELSE
							SET @msg = CONCAT('Style does not have enough stock (stock available: ',(CAST(@stock_qty AS SIGNED)-CAST(@reserved_in_orders AS SIGNED)),')');
							SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
						END IF;
						
					END IF;
					
				END IF;
			END IF;
		END IF;
	END IF;
	
	/*
	IF NEW.alloted_qty THEN 
		IF(NEW.alloted_qty <> OLD.alloted_qty) THEN
			IF((OLD.qty = NEW.alloted_qty) AND (NEW.alloted_qty<>0)) THEN
				SET NEW.status_id = 6; /* received 
			END IF;
			IF((OLD.qty > NEW.alloted_qty) AND (NEW.alloted_qty<>0)) THEN
				SET NEW.status_id = 7; /* part received 
			END IF;
			/* watches log for item received here
		END IF ;
	END IF;
	*/
	
	IF IFNULL(NEW.status_id,OLD.status_id)<>OLD.status_id THEN 
		IF IFNULL(NEW.status_id,'')<>'' THEN
			IF NEW.status_id<>OLD.status_id THEN
				SET NEW.status_history = CONCAT(OLD.status_id,',',CURRENT_TIMESTAMP(),',',NEW.status_history,'###',IFNULL(OLD.status_history,''));
			ELSE 
				SET NEW.status_history=OLD.status_history;
			END IF;
			
		END IF;
	END IF;
	
	IF NEW.qty IS NOT NULL THEN
		IF NEW.qty = 0 THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot set qty to zero. Please delete line instead';
		END IF;
	END IF;
}
AFTER UPDATE {
	IF (OLD.qty<>NEW.qty) OR (OLD.sell_price<>NEW.sell_price) THEN
		SET @total_for_order = (SELECT SUM(qty*(IF(discount_type=0,sell_price*(1-(discount/100)),sell_price-discount))) FROM orders_details WHERE order_id=OLD.order_id);
		UPDATE orders SET grand_total = IFNULL(@total_for_order,0) WHERE id=OLD.order_id;
	END IF;
	
	UPDATE styles_cs SET reserved_qty = styleReservedQty(NEW.style_cs_id) WHERE id=OLD.style_cs_id;
	
	IF IFNULL(NEW.qty,OLD.qty)<>OLD.qty THEN
		IF IFNULL(NEW.qty,0)>0 THEN
			IF NEW.qty < OLD.qty THEN 
				IF NEW.qty >= IFNULL((SELECT SUM(invoiced_qty*IF(invoice_sell_price<0,-1,1)) FROM invoice_details WHERE NEW.id=order_details_id),0)  THEN
					IF OLD.po_detail_id>0 THEN
						SET @alloted_qty = CAST(OLD.alloted_qty AS SIGNED);
						IF @alloted_qty=0 THEN
							SET @reserved_qty = (SELECT SUM(qty-IFNULL(alloted_qty,0)) as reserved FROM orders_details WHERE po_detail_id = NEW.po_detail_id);
							UPDATE po_detail SET reserved=@reserved_qty, audit_updated_by=CONCAT('orders_details trigger'), audit_updated_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger' WHERE id=NEW.po_detail_id;
						ELSE
							
							
							IF @alloted_qty >= NEW.qty THEN
								SET @reserved_qty = (SELECT SUM(qty-IFNULL(alloted_qty,0)) as reserved FROM orders_details WHERE po_detail_id = NEW.po_detail_id);
								UPDATE po_detail SET reserved=@reserved_qty, audit_updated_by=CONCAT('orders_details trigger'), audit_updated_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger' WHERE id=NEW.po_detail_id;
								
								INSERT INTO po_received_allotment SET po_detail_id=NEW.po_detail_id, order_detail_id=NEW.id, qty_alloted = (CAST(NEW.qty AS SIGNED)-@alloted_qty), audit_created_by=CONCAT('orders_details trigger'), audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
								
								INSERT INTO po_received_allotment SET po_detail_id=NEW.po_detail_id, order_detail_id=0, qty_alloted = (@alloted_qty-NEW.qty), audit_created_by=CONCAT('orders_details trigger'), audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
								
							ELSE
								SET @qty = NEW.qty-IFNULL(@alloted_qty,0);
								
								SET @reserved_qty = (SELECT reserved FROM po_detail WHERE id=NEW.po_detail_id);
								IF @reserved_qty>=@qty THEN
									
									SET @reserved_qty = (SELECT SUM(qty-IFNULL(alloted_qty,0)) as reserved FROM orders_details WHERE po_detail_id = NEW.po_detail_id);
									UPDATE po_detail SET reserved=@reserved_qty, audit_updated_by=CONCAT('orders_details trigger'), audit_updated_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger' WHERE id=NEW.po_detail_id;
									
								ELSE 
									SET @msg = CONCAT('Alloted(',IFNULL(@alloted_qty,0),')+Reserved(',IFNULL(@reserved_qty,0),') Qty is lower than Order Qty(',OLD.qty,')! Cannot continue!');
									SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
								END IF;
								
							END IF;
						END IF;
					END IF;
				ELSE
					SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New qty is lower than invoiced qty';
				END IF;
			ELSE
				IF NEW.qty > OLD.qty THEN
					SET @qty = NEW.qty - OLD.qty;
					IF IFNULL(OLD.po_detail_id,0)>0 THEN
						SET @po_qty = (SELECT qty FROM po_detail WHERE id=OLD.po_detail_id);
						SET @reserved_qty = (SELECT reserved FROM po_detail WHERE id=NEW.po_detail_id);
						SET @sent_in_stock = (SELECT sent_in_stock FROM po_detail WHERE id=NEW.po_detail_id);
						SET @received = (SELECT received FROM po_detail WHERE id=NEW.po_detail_id);
						
						IF (@po_qty-@reserved_qty-IFNULL(@sent_in_stock,0)) >= @qty THEN
							SET @reserved_qty = (SELECT SUM(qty-IFNULL(alloted_qty,0)) as reserved FROM orders_details WHERE po_detail_id = NEW.po_detail_id);
							UPDATE po_detail SET reserved=@reserved_qty, audit_updated_by=CONCAT('orders_details trigger'), audit_updated_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger' WHERE id=NEW.po_detail_id;
							
						ELSE
							SET @msg = CONCAT('Qty cannot be greater than available Qty in PO(',(IFNULL(@po_qty,0)-IFNULL(@reserved_qty,0)-IFNULL(@sent_in_stock,0)),')');
							
							SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
						END IF;
					
						
					END IF;
					
				END IF;
			END IF;
		END IF;
		
		UPDATE orders SET total_qty = IFNULL((SELECT SUM(CAST(qty AS UNSIGNED)-CAST(LEAST(qty,returned_qty) AS UNSIGNED)) FROM orders_details WHERE order_id=NEW.order_id),0)+IFNULL((SELECT SUM(qty) FROM orders_request WHERE order_id=NEW.order_id),0) WHERE id=NEW.order_id;
	END IF;
}
AFTER INSERT {
	SET @total_for_order = (SELECT SUM(qty*(IF(discount_type=0,sell_price*(1-(discount/100)),sell_price-discount))) FROM orders_details WHERE order_id=NEW.order_id);
	UPDATE orders SET grand_total = IFNULL(@total_for_order,0) WHERE id=NEW.order_id;
	
	UPDATE styles_cs SET reserved_qty = styleReservedQty(NEW.style_cs_id) WHERE id=NEW.style_cs_id;
	
	IF NEW.original_order_detail_id > 0 THEN
		/*CALL update_order_detail_line_dropship_splitted(NEW.original_order_detail_id);*/
		INSERT INTO delayed_update SET table_name="orders_details", field_name="dropship_splitted_line", new_value=1, table_id=NEW.original_order_detail_id;
	END IF;
	
	IF NEW.po_detail_id > 0 THEN
		SET @reserved_qty = (SELECT SUM(qty-IFNULL(alloted_qty,0)) as reserved FROM orders_details WHERE po_detail_id = NEW.po_detail_id);
		UPDATE po_detail SET reserved=@reserved_qty, audit_updated_by=CONCAT('orders_details trigger'), audit_updated_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger' WHERE id=NEW.po_detail_id;
	END IF;
	
	SET @store_address_id = (SELECT store_address_id FROM orders WHERE id=NEW.order_id);
	IF @store_address_id>0 THEN
		SET @date_orders_start = DATE_SUB(NOW(), INTERVAL 12 MONTH);
		SET @ordered_last_12_month = IFNULL((SELECT SUM(qty) FROM orders_details LEFT JOIN orders o ON o.id=orders_details.order_id WHERE orders_details.audit_created_date > @date_orders_start AND store_address_id=@store_address_id),0);
		UPDATE m_store_address SET last_qty_ordered = @ordered_last_12_month WHERE store_id=(SELECT store_id FROM orders WHERE id =NEW.order_id);
	END IF;

	UPDATE orders SET total_qty = IFNULL((SELECT SUM(CAST(qty AS UNSIGNED)-CAST(LEAST(qty,returned_qty) AS UNSIGNED)) FROM orders_details WHERE order_id=NEW.order_id),0)+IFNULL((SELECT SUM(qty) FROM orders_request WHERE order_id=NEW.order_id),0) WHERE id=NEW.order_id;
}
BEFORE INSERT {
	/*audit_sql*/
	
	IF @dont_check_po_availability IS NULL OR @dont_check_po_availability=0 THEN
		SET @total_alloted = (SELECT SUM(qty_alloted) FROM po_received_allotment WHERE po_detail_id=NEW.po_detail_id);
		SET @po_qty = (SELECT qty FROM po_detail WHERE id=NEW.po_detail_id);
		
		IF (@total_alloted) > @po_qty THEN
			SET @msg = CONCAT('Integroty error. PO#',(SELECT po_id FROM po_detail WHERE id=NEW.po_detail_id),' is over alloted');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
	
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');

	SET @preview_entry = (SELECT abs(TO_SECONDS(audit_created_date)-TO_SECONDS(NEW.audit_created_date)) FROM orders_details WHERE order_id = NEW.order_id AND style_cs_id = NEW.style_cs_id order by id desc limit 1);
	if @preview_entry <= 7 THEN 
			SET @msg = CONCAT('WAIT !!!\n',NEW.style_name,' ',NEW.color_name,' ',NEW.size_name,' already exists in this order, please update quantity instead or wait 7 seconds before adding a duplicate.');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;

	
	IF IFNULL(NEW.po_detail_id,0)=0 THEN
		SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=NEW.style_cs_id);
		IF @stock_cs_id IS NULL THEN
			INSERT INTO styles_stock SET style_cs_id=NEW.style_cs_id;
			SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=NEW.style_cs_id);
		END IF;
		
		SET NEW.alloted_qty = NEW.qty;
		
		SET @available_to_sell = (SELECT qty_in_stock FROM styles_stock WHERE styles_cs_id=NEW.style_cs_id) - (select IFNULL(sum(qty-returned_qty-invoiced_qty),0) from orders_details where po_detail_id=0 AND NEW.style_cs_id = orders_details.style_cs_id and status_id IN (6,8));
		
		IF NEW.qty>@available_to_sell THEN
			SET @msg = CONCAT('Cannot add ',NEW.qty,'. Stock for ',NEW.style_name,'/',NEW.color_name,'/',NEW.size_name,' is ',@available_to_sell);
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
		
		
		SET NEW.status_id='6'; /* from stock => status received */ 
		
	END IF;
	
	IF @dont_check_po_availability IS NULL OR @dont_check_po_availability=0 THEN
		IF IFNULL(NEW.po_detail_id,0)>0 THEN
		
			SET NEW.status_id='1'; /* from po => confirm_by_factory=> status Coming */ 
			
			SET @po_available = (SELECT qty-GREATEST(reserved,received) FROM po_detail WHERE id=NEW.po_detail_id);
			IF NEW.qty>@po_available THEN 
				SET @msg = CONCAT('Cannot add ',NEW.qty,'. PO available for ',NEW.style_name,'/',NEW.color_name,'/',NEW.size_name,' is ',@po_available);
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
			END IF;
		END IF;
	END IF;
	
	SET NEW.sell_price = (SELECT computed_price FROM styles_cs WHERE id=NEW.style_cs_id); /*(SELECT price FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id));*/
	
	SET NEW.shipping_type = (SELECT MIN(id) FROM mm_shipping_types);
	
	IF NEW.bridal_extra_charge THEN
		SET NEW.sell_price = NEW.sell_price+NEW.bridal_extra_charge;
	END IF;
	
	SET @store_discount = (SELECT store_discount_level FROM m_store WHERE id=(SELECT store_id FROM orders WHERE id=NEW.order_id));
	IF IFNULL(@store_discount,0)>0 THEN
		SET @discount = (SELECT discount_percentage FROM mm_discount_level WHERE id=@store_discount);
		SET NEW.discount = @discount;
		SET NEW.discount_type = '0';
	END IF;
	
}
BEFORE DELETE {
	/*audit_sql*/
	
	/*deleted_tables_sql*/
}
AFTER DELETE {
	IF OLD.original_order_detail_id > 0 THEN
		SET @has_child_dropships = (SELECT COUNT(*) FROM orders_details WHERE original_order_detail_id=OLD.original_order_detail_id);
		/*UPDATE orders_details SET dropship_splitted_line=IF(@has_child_dropships,1,0) WHERE id=OLD.original_order_detail_id;*/
		INSERT INTO delayed_update SET table_name="orders_details", field_name="dropship_splitted_line", new_value=IF(@has_child_dropships,1,0), table_id=OLD.original_order_detail_id;
	END IF;
	
	IF OLD.po_detail_id > 0 THEN
		IF OLD.alloted_qty>0 THEN
			SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=(SELECT style_cs_id FROM po_detail WHERE id=OLD.po_detail_id));

			INSERT INTO styles_stock_adj SET instock_styles_cs_id=@stock_cs_id, qty=OLD.alloted_qty, reason=CONCAT('Order #',OLD.order_id,' line deleted'), audit_created_by=CONCAT('orders_details trigger'), audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
		END IF;
		
		SET @coming_qty = IFNULL(OLD.qty - IFNULL(OLD.alloted_qty,0),0);
		
		IF @coming_qty>0 THEN
			/*UPDATE po_detail SET reserved=reserved-@coming_qty, audit_updated_by=CONCAT('orders_details trigger'), audit_updated_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger' WHERE id=OLD.po_detail_id;*/
			SET @reserved_qty = (SELECT SUM(qty-IFNULL(alloted_qty,0)) as reserved FROM orders_details WHERE po_detail_id = OLD.po_detail_id);
			UPDATE po_detail SET reserved=IFNULL(@reserved_qty,0), audit_updated_by=CONCAT('orders_details trigger'), audit_updated_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger' WHERE id=OLD.po_detail_id;
		END IF;
	END IF;

	
	
	UPDATE styles_cs SET reserved_qty = styleReservedQty(OLD.style_cs_id) WHERE id=OLD.style_cs_id;
	
	UPDATE orders SET total_qty = IFNULL((SELECT SUM(CAST(qty AS UNSIGNED)-CAST(LEAST(qty,returned_qty) AS UNSIGNED)) FROM orders_details WHERE order_id=OLD.order_id),0)+IFNULL((SELECT SUM(qty) FROM orders_request WHERE order_id=OLD.order_id),0) WHERE id=OLD.order_id;
}
DEF:po_detail
BEFORE DELETE {
	/*audit_sql*/
	
	IF OLD.reserved>0 OR OLD.received>0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete PO line. It already has reserved or received item';
	END IF;
	
	UPDATE orders_details SET po_id='' WHERE po_detail_id=OLD.id;
	
	
	SET @total_qty = (SELECT SUM(qty) FROM po_detail WHERE po_id=OLD.po_id);
	SET @total_received = (SELECT SUM(received) FROM po_detail WHERE po_id=OLD.po_id);
	IF @total_qty=@total_received THEN
		SET @msg = CONCAT('PO 2 ',OLD.po_id,' has all items received. No further changes allowed (qty:',@total_qty,', rec:',@total_received,')');
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;

}
AFTER DELETE {
	UPDATE po SET yet_to_ship=((SELECT SUM(qty) FROM po_detail WHERE po_id=po.id)-(SELECT SUM(qty) FROM packingslip_details WHERE (SELECT po_id FROM po_detail WHERE id=po_detail_id)=po.id AND (SELECT tracking_number FROM packingslip WHERE id=packingslip_id)<>'')), audit_updated_by=CONCAT('po_detail trigger') WHERE id=OLD.po_id;
}
BEFORE UPDATE {
	/*audit_sql*/
	
	IF OLD.qty>NEW.qty THEN
		IF NEW.qty<OLD.reserved OR NEW.qty<OLD.received THEN
			SET @msg = CONCAT('Cannot decrease quantity. Should be higher than reserved(',OLD.reserved,') and received(',OLD.received,')');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
	
	IF NEW.received > OLD.received THEN
		IF NEW.received>OLD.qty THEN
			SET @msg = CONCAT('Cannot receive more than PO line Qty(',OLD.qty,') ');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
	
	SET @total_qty = IFNULL((SELECT SUM(qty-IFNULL(alloted_qty,0)) FROM orders_details WHERE po_detail_id=OLD.id),0);
	
	/*SET @msg = CONCAT('',NEW.reserved,' <>', @total_qty, ' view ',NEW.audit_updated_by);
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;	*/
	
	IF NEW.reserved THEN 
		IF (NEW.reserved<>@total_qty) AND NEW.audit_updated_by NOT LIKE "% trigger" THEN
			SET @msg = CONCAT('Inconsistency error. Reserved Qty has to match the sum of all Qty receiving from this line (',NEW.reserved,'<>',@total_qty,')');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
	
	IF (OLD.qty<>NEW.qty) OR (OLD.received<>NEW.received) THEN
		SET NEW.total_coming = NEW.qty - NEW.received;
	END IF;
	
	
	/*SET NEW.available_to_sell=((IFNULL(NEW.total_coming,OLD.total_coming)+IFNULL(NEW.received,OLD.received))-(IFNULL(NEW.reserved,OLD.reserved)+IFNULL(NEW.sent_in_stock,OLD.sent_in_stock)));*/
	SET NEW.available_to_sell=IFNULL(NEW.qty,OLD.qty) - GREATEST(IFNULL(NEW.reserved,OLD.reserved),IFNULL(NEW.received,OLD.received));
	
	IF @dont_check_po_consistency_from_order_delete IS NULL OR @dont_check_po_consistency_from_order_delete=0 THEN
		
		SET @dqty = IFNULL(NEW.qty,OLD.qty);
		SET @dtotal_coming = IFNULL(NEW.total_coming,OLD.total_coming);
		SET @dreceived = IFNULL(NEW.received,OLD.received);
		
		IF @dqty<>(@dtotal_coming+@dreceived) THEN
			SET @msg = CONCAT('Inconsistency error for line po_detail ',NEW.id,'. Qty has to match coming + received (',@dqty,'<>(',@dtotal_coming,'+',@dreceived,'))');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
	
	
	SET @sent_in_stock = (SELECT SUM(qty_alloted) FROM po_received_allotment WHERE po_detail_id=NEW.id AND order_detail_id=0);
	SET @total_alloted = (SELECT SUM(qty_alloted) FROM po_received_allotment WHERE po_detail_id=NEW.id);
	

	IF NEW.sent_in_stock<>OLD.sent_in_stock THEN
		IF @sent_in_stock<>NEW.sent_in_stock THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inconsistency error. Sent in stock has to match alloted qty';
		END IF;
	END IF;
	
	IF NEW.received<>OLD.received THEN 
		IF @total_alloted<>NEW.received THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inconsistency error. Received Qty has to match alloted qty + sent to stock qty';
		END IF;
	END IF;
	
	IF OLD.style_cs_id<>NEW.style_cs_id THEN
		SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
		SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
		SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	END IF;
	
	IF ((NEW.received<>OLD.received) AND (NEW.qty=NEW.received)) THEN
		SET NEW.completed=1;
	END IF;
	
	IF NEW.audit_updated_by NOT LIKE '%nocheck%' THEN
		SET @total_qty = (SELECT SUM(qty) FROM po_detail WHERE po_id=OLD.po_id);
		SET @total_received = (SELECT SUM(received) FROM po_detail WHERE po_id=OLD.po_id);
		IF @total_qty=@total_received THEN
			IF @dont_check_po_consistency_from_order_delete IS NULL OR @dont_check_po_consistency_from_order_delete=0 THEN
				SET @msg = CONCAT('PO 3 ',OLD.po_id,' has all items received. No further changes allowed (qty:',@total_qty,', rec:',@total_received,')');
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
			END IF;
		END IF;
	END IF;
}
AFTER UPDATE {

	SET @total_qty = IFNULL((SELECT SUM(qty) FROM po_detail WHERE po_id = NEW.po_id),0);
	SET @total_received = IFNULL((SELECT SUM(received) FROM po_detail WHERE po_id = NEW.po_id),0);
	
	/* change status to received*/
	IF(@total_qty <= @total_received) THEN
		UPDATE po SET status=7, audit_updated_by=CONCAT('po_detail trigger') WHERE id = NEW.po_id;
	END IF;
	
	/* change status to part received*/
	IF((@total_qty > @total_received) AND (@total_received>0)) THEN
		UPDATE po SET status=6, audit_updated_by=CONCAT('po_detail trigger') WHERE id = NEW.po_id;
	END IF;
		
	IF OLD.received<>NEW.received THEN
		SET @style_id = (SELECT style_id FROM styles_cs WHERE id=OLD.style_cs_id);
		SET @total_coming = (SELECT SUM(total_coming) FROM po_detail LEFT JOIN styles_cs ON styles_cs.id=style_cs_id WHERE style_id=@style_id);
		UPDATE styles SET total_coming=@total_coming WHERE id=@style_id;
	END IF;
	
	IF IFNULL(NEW.qty,0)<>0 THEN
		IF OLD.qty<>NEW.qty THEN
			UPDATE po SET yet_to_ship=((SELECT SUM(qty) FROM po_detail WHERE po_id=po.id)-IFNULL((SELECT SUM(qty) FROM packingslip_details WHERE (SELECT po_id FROM po_detail WHERE id=po_detail_id)=po.id AND (SELECT tracking_number FROM packingslip WHERE id=packingslip_id)<>''),0)), audit_updated_by=CONCAT('po_detail trigger') WHERE id=NEW.po_id;
		END IF;
	END IF;
}
AFTER INSERT {
	SET @style_id = (SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id);
	SET @total_coming = (SELECT SUM(total_coming) FROM po_detail LEFT JOIN styles_cs ON styles_cs.id=style_cs_id WHERE style_id=@style_id);
	UPDATE styles SET total_coming=@total_coming WHERE id=@style_id;
	
	IF @dont_update_yet_to_ship IS NULL OR @dont_update_yet_to_ship=0 THEN
		UPDATE po SET yet_to_ship=((SELECT SUM(qty) FROM po_detail WHERE po_id=po.id)-(SELECT SUM(qty) FROM packingslip_details WHERE (SELECT po_id FROM po_detail WHERE id=po_detail_id)=po.id AND (SELECT tracking_number FROM packingslip WHERE id=packingslip_id)<>'')), audit_updated_by=CONCAT('po_detail trigger') WHERE id=NEW.po_id;
	END IF;
}
BEFORE INSERT {
	/*audit_sql*/
	
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	
	SET NEW.available_to_sell = NEW.qty;
	
	IF NEW.audit_created_by NOT LIKE '%trigger' THEN
		SET @total_qty = (SELECT SUM(qty) FROM po_detail WHERE po_id=NEW.po_id);
		SET @total_received = (SELECT SUM(received) FROM po_detail WHERE po_id=NEW.po_id);
		IF @total_qty=@total_received THEN
			SET @msg = CONCAT('PO 1 ',NEW.po_id,' has all items received. No further changes allowed (qty:',@total_qty,', rec:',@total_received,')');
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
}
DEF:po_received_allotment
BEFORE INSERT {
	/*audit_sql*/
	
	IF IFNULL(NEW.packingslip_details_id,0)>0 THEN 
		
			SET @accepted_qty = (SELECT (qty-received_qty) FROM packingslip_details WHERE id = NEW.packingslip_details_id);
			
			IF @resting_items_to_receive_in_packing_line IS NOT NULL THEN
				IF @resting_items_to_receive_in_packing_line=0 THEN
					IF (NEW.qty_alloted>@accepted_qty) THEN
						
						SET @exceed_qty = (NEW.qty_alloted-@accepted_qty);
						
						INSERT INTO shipment_discrepancy SET packingslip_detail_id=NEW.packingslip_details_id , qty=@exceed_qty, comments=CONCAT('Packing Detail# ',NEW.packingslip_details_id,' ',IF(@exceed_qty<0,'short by','exceeded by'),' qty:',@exceed_qty) ,audit_created_by=CONCAT('po_received_allotment trigger'), audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
						
						SET NEW.qty_alloted = @accepted_qty;
						
					END IF;
					
					IF(NEW.qty_alloted<@accepted_qty) THEN
						
						SET @exceed_qty =  CAST((NEW.qty_alloted-@accepted_qty) AS SIGNED);
						
						INSERT INTO shipment_discrepancy SET packingslip_detail_id=NEW.packingslip_details_id , qty=@exceed_qty, comments=CONCAT('Packing Detail# ',NEW.packingslip_details_id,' exceed qty:',@exceed_qty) ,audit_created_by='po_received_allotment trigger', audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
						SET @shipment_discrepancy_id = (SELECT LAST_INSERT_ID());
						UPDATE packingslip_details SET qty=NEW.qty_alloted,audit_updated_by='po_received_allotment trigger' WHERE id=NEW.packingslip_details_id;
						
						SET @packing_id = (SELECT packingslip_id FROM packingslip_details WHERE id = NEW.packingslip_details_id);
						SET @grand_total = IFNULL((SELECT grand_total FROM factory_invoice WHERE packinglist_id=@packing_id),0);
						SET @payments_total = IFNULL((SELECT payments_total FROM factory_invoice WHERE packinglist_id=@packing_id),0);
						
						IF (@payments_total>@grand_total) THEN
							
							SET @vendor_id = IFNULL((SELECT vendor_id FROM factory_invoice WHERE packinglist_id=@packing_id),0);
							SET @factory_invoice_id = IFNULL((SELECT id FROM factory_invoice WHERE packinglist_id=@packing_id),0);
							SET @credit = @payments_total-@grand_total;
							/* save deposit with credit to vendor*/
							INSERT INTO  factory_deposits SET vendor_id=@vendor_id, deposit_amount=@credit, used_amount=0, wire_details='', shipment_discrepancy_id=@shipment_discrepancy_id,audit_created_by='po_received_allotment trigger';
							/* save nagetive factory payment to compensate grand total and payment_total*/
							INSERT INTO factory_payments SET vendor_id=@vendor_id, amount=(@credit*(-1)), factory_invoice_id=@factory_invoice_id, wire_details='',deposit_id=0,audit_created_by='po_received_allotment trigger';
						END IF;
						/*SET @msg = CONCAT('excedente negativo:',@exceed_qty);
						SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;*/
					END IF;
				END IF;
			END IF;
			
			SET @total_alloted = IFNULL((SELECT SUM(qty_alloted) FROM po_received_allotment WHERE po_detail_id=NEW.po_detail_id),0);
			SET @po_qty = (SELECT qty FROM po_detail WHERE id=NEW.po_detail_id);

			/*IF NEW.order_detail_id = 0 THEN
				SET @msg = CONCAT('',@total_alloted,' +', NEW.qty_alloted, '> ',@po_qty);
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
			END IF;*/
			
			/*
				aca verifico si el invoice tiene pagos mayores a grand total
			*/

			IF (@total_alloted+NEW.qty_alloted) > @po_qty THEN
				SET @msg = CONCAT('Cannot alloted more than PO line Qty(',@po_qty,') ');
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
			END IF;

			UPDATE packingslip_details SET received_qty=NEW.qty_alloted+received_qty, date_received=CURRENT_TIMESTAMP() WHERE id=NEW.packingslip_details_id;
			
	END IF;
}
AFTER INSERT {
	SET @sent_in_stock = IFNULL((SELECT SUM(qty_alloted) FROM po_received_allotment WHERE po_detail_id=NEW.po_detail_id AND order_detail_id=0),0);
	SET @total_alloted = IFNULL((SELECT SUM(qty_alloted) FROM po_received_allotment WHERE po_detail_id=NEW.po_detail_id),0);
	
	IF NEW.order_detail_id=0 THEN
		SET @stock_cs_id = (SELECT id FROM styles_stock WHERE styles_cs_id=(SELECT style_cs_id FROM po_detail WHERE id=NEW.po_detail_id));

		INSERT INTO styles_stock_adj SET instock_styles_cs_id=@stock_cs_id, qty=NEW.qty_alloted, reason=CONCAT('PO #',(SELECT po_id FROM po_detail WHERE id=NEW.po_detail_id),' updated sent in stock'), audit_created_by=CONCAT('po_received_allotment trigger'), audit_created_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger';
	ELSE
		IF (NEW.audit_created_by NOT LIKE '%trigger') OR IFNULL(NEW.packingslip_details_id,0)>0 THEN
			UPDATE orders_details SET alloted_qty=IFNULL(alloted_qty,0)+NEW.qty_alloted WHERE id=NEW.order_detail_id;
			
			SET @alloted_in_detail = (SELECT alloted_qty FROM orders_details WHERE id=NEW.order_detail_id);
			SET @order_detail_qty = (SELECT qty FROM orders_details WHERE id=NEW.order_detail_id);
			
			SET @po_id = (SELECT po_id FROM po_detail WHERE id=NEW.po_detail_id);
			
			IF @alloted_in_detail<@order_detail_qty THEN
				UPDATE orders_details SET status_id=7,status_history=CONCAT('poreceived',',',@po_id,',',@app_username) WHERE id=NEW.order_detail_id;
			ELSE
				UPDATE orders_details SET status_id=6,status_history=CONCAT('poreceived',',',@po_id,',',@app_username) WHERE id=NEW.order_detail_id;
			END IF;
			
			/* watches_log for item received */
			SET @store_id = IFNULL((SELECT store_id FROM orders WHERE id=(SELECT order_id FROM orders_details WHERE id=NEW.order_detail_id)),0);
			SET @order_id = IFNULL((SELECT order_id FROM orders_details WHERE id=NEW.order_detail_id),0);
			INSERT INTO watches_log SET m_watches_id=8, store_id=@store_id, order_id=@order_id, order_detail_id=NEW.order_detail_id, qty=NEW.qty_alloted;
			
			/* watches_log for rush item received*/
			SET @rush_requested_detail_id = IFNULL((SELECT rush_requested_detail.id FROM rush_requested_detail LEFT JOIN rush_request ON rush_request.id = rush_requested_detail.rush_request_id WHERE rush_request.rushed=1 AND order_detail_id=NEW.order_detail_id),0);
			SET @rush_requested_qty = IFNULL((SELECT rush_request.rush_qty FROM rush_requested_detail LEFT JOIN rush_request ON rush_request.id = rush_requested_detail.rush_request_id WHERE rush_request.rushed=1 AND order_detail_id=NEW.order_detail_id),0);
			
			IF((@rush_requested_detail_id>0) AND (@rush_requested_qty>0)) THEN
				INSERT INTO watches_log SET m_watches_id=6, store_id=@store_id, order_id=@order_id, order_detail_id=NEW.order_detail_id, qty=@rush_requested_qty, rush_requested_detail_id=@rush_requested_detail_id;
			END IF;
		END IF;
	END IF;
	
	
	
	UPDATE po_detail SET sent_in_stock=@sent_in_stock,received=@total_alloted, audit_updated_by=CONCAT('po_received_allotment nocheck trigger') WHERE id=NEW.po_detail_id;
	UPDATE po_detail SET total_coming=qty-received, audit_updated_by=CONCAT('po_received_allotment nocheck trigger') WHERE id=NEW.po_detail_id;
	/*UPDATE po_detail SET available_to_sell=((total_coming+received)-(reserved+sent_in_stock)), audit_updated_by=CONCAT('po_received_allotment nocheck trigger') WHERE id=NEW.po_detail_id;*/
	UPDATE po_detail SET available_to_sell=(qty - GREATEST(reserved,received)), audit_updated_by=CONCAT('po_received_allotment nocheck trigger') WHERE id=NEW.po_detail_id;
}
DEF:styles_stock_adj
AFTER INSERT {
	UPDATE styles_stock SET qty_in_stock = qty_in_stock + NEW.qty, audit_updated_by=CONCAT('styles_stock_adj trigger'), audit_updated_date=CURRENT_TIMESTAMP(), audit_ip='MySQL stored trigger' WHERE id=NEW.instock_styles_cs_id;
}
DEF:styles_stock
BEFORE UPDATE {
	/*audit_sql*/
	
	IF (OLD.qty_in_stock+NEW.qty_in_stock)<0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Negative stock is invalid. You can'' add this item';
	END IF;
}
AFTER UPDATE {
	SET @style_id = (SELECT style_id FROM styles_cs WHERE id=OLD.styles_cs_id);
	SET @total_stock = (SELECT SUM(qty_in_stock) FROM styles_stock WHERE (SELECT style_id FROM styles_cs WHERE id=styles_cs_id)=@style_id);
	UPDATE styles SET total_stock=@total_stock WHERE id=@style_id;
}
BEFORE INSERT {
	/*audit_sql*/
	
	IF (NEW.qty_in_stock)<0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Negative stock is invalid. You can'' add this item';
	END IF;
}
AFTER INSERT {
	SET @style_id = (SELECT style_id FROM styles_cs WHERE id=NEW.styles_cs_id);
	SET @total_stock = (SELECT SUM(qty_in_stock) FROM styles_stock WHERE (SELECT style_id FROM styles_cs WHERE id=styles_cs_id)=@style_id);
	UPDATE styles SET total_stock=@total_stock WHERE id=@style_id;
}
DEF:styles_cs
BEFORE INSERT {
	/*audit_sql*/
	
	SET @is_repeated = (SELECT COUNT(*) FROM styles_cs WHERE style_id=NEW.style_id AND color_id=NEW.color_id AND size_id=NEW.size_id);
	IF @is_repeated>0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are adding a duplicated combination';
	END IF;
	
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=NEW.style_id),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=NEW.color_id),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=NEW.size_id),'');
	
	SET @price = (SELECT price from styles where id = NEW.style_id)+NEW.price_difference;
	SET NEW.computed_price = @price;	
}
BEFORE UPDATE {
	/*audit_sql*/
	
	IF NEW.product_id<>OLD.product_id THEN
		IF OLD.product_id IS NOT NULL OR OLD.product_id<>'' THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Combination already has UPC code. Cannot update';
		END IF;
	END IF;
	
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=NEW.style_id),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=NEW.color_id),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=NEW.size_id),'');
	SET @price = (SELECT price from styles where id = NEW.style_id)+NEW.price_difference;
	SET NEW.computed_price = @price;
	
}
AFTER INSERT {
	INSERT INTO styles_stock SET styles_cs_id=NEW.id, qty_in_stock=0,audit_created_by=CONCAT('styles_cs trigger');
}
DEF:orders_request
BEFORE INSERT {
	/*audit_sql*/
	
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
	
	SET @store_discount = (SELECT store_discount_level FROM m_store WHERE id=(SELECT store_id FROM orders WHERE id=NEW.order_id));
	IF IFNULL(@store_discount,0)>0 THEN
		SET @discount = (SELECT discount_percentage FROM mm_discount_level WHERE id=@store_discount);
		SET NEW.discount = @discount;
	END IF;
}
AFTER INSERT {
	UPDATE orders SET total_qty = IFNULL((SELECT SUM(CAST(qty AS UNSIGNED)-CAST(LEAST(qty,returned_qty) AS UNSIGNED)) FROM orders_details WHERE order_id=NEW.order_id),0)+IFNULL((SELECT SUM(qty) FROM orders_request WHERE order_id=NEW.order_id),0) WHERE id=NEW.order_id;
}
BEFORE UPDATE {
	/*audit_sql*/
	
	
	IF IFNULL(OLD.order_id,0)<>IFNULL(NEW.order_id,0) THEN
		SET @store_discount = (SELECT store_discount_level FROM m_store WHERE id=(SELECT store_id FROM orders WHERE id=NEW.order_id));
		IF IFNULL(@store_discount,0)>0 THEN
			SET @discount = (SELECT discount_percentage FROM mm_discount_level WHERE id=@store_discount);
			SET NEW.discount = @discount;
		END IF;
	END IF;
	
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
}
AFTER UPDATE {
	UPDATE orders SET total_qty = IFNULL((SELECT SUM(CAST(qty AS UNSIGNED)-CAST(LEAST(qty,returned_qty) AS UNSIGNED)) FROM orders_details WHERE order_id=NEW.order_id),0)+IFNULL((SELECT SUM(qty) FROM orders_request WHERE order_id=NEW.order_id),0) WHERE id=NEW.order_id;
}
BEFORE DELETE {
	/*audit_sql*/
	
	 /*deleted_tables_sql*/
}
AFTER DELETE {
	UPDATE orders SET total_qty = IFNULL((SELECT SUM(CAST(qty AS UNSIGNED)-CAST(LEAST(qty,returned_qty) AS UNSIGNED)) FROM orders_details WHERE order_id=OLD.order_id),0)+IFNULL((SELECT SUM(qty) FROM orders_request WHERE order_id=OLD.order_id),0) WHERE id=OLD.order_id;
}
DEF:rush_request
AFTER INSERT {
	UPDATE orders_details SET rush_requested=1 WHERE id=NEW.order_detail_id;
}
AFTER DELETE {
	SET @rushrequested=(SELECT COUNT(*) FROM rush_request WHERE IFNULL(cancelled,0)=0 AND order_detail_id=OLD.order_detail_id);
	UPDATE orders_details SET rush_requested=IF(@rushrequested,1,0) WHERE id=OLD.order_detail_id;
}
AFTER UPDATE {
	SET @rushrequested=(SELECT COUNT(*) FROM rush_request WHERE IFNULL(cancelled,0)=0 AND order_detail_id=NEW.order_detail_id);
	SET @rushed=(SELECT COUNT(*) FROM rush_request WHERE IFNULL(rushed,0)=1 AND IFNULL(cancelled,0)=0 AND order_detail_id=NEW.order_detail_id);
	UPDATE orders_details SET rush_requested=IF(@rushrequested,1,0),rushed=@rushed WHERE id=NEW.order_detail_id;
	
	
	IF IFNULL(NEW.cancelled,0) <> IFNULL(OLD.cancelled,0) THEN 
		IF IFNULL(NEW.cancelled,0)>0 THEN
			DELETE FROM rush_requested_detail WHERE rush_request_id = OLD.id;
		END IF;
	END IF;
	
}
DEF:po
AFTER UPDATE {
	IF NEW.arrival_date THEN
		IF OLD.arrival_date<>NEW.arrival_date THEN
			UPDATE orders_details SET po_coming_date=NEW.arrival_date WHERE (SELECT COUNT(*) FROM po_detail WHERE po_id=NEW.id AND id=po_detail_id)>0;
		END IF;
	END IF;
	
	IF NEW.confirm>0 THEN
		IF NEW.confirm<>OLD.confirm THEN
			UPDATE orders_details SET status_id=IF(status_id=1,11,status_id),status_history=CONCAT('po_confirmed',',',NEW.id,',',@app_username) WHERE (SELECT po_id FROM po_detail WHERE id=orders_details.po_detail_id)=NEW.id;
		END IF;
	END IF;
}
BEFORE UPDATE {
	/*audit_sql*/
	
	IF NEW.date_to_ship_from_vendor<>OLD.date_to_ship_from_vendor THEN
		SET NEW.arrival_date = IFNULL(DATE_FORMAT(DATE_ADD(NEW.date_to_ship_from_vendor,INTERVAL (SELECT buffer_days FROM m_vendors WHERE id=NEW.vendor_id) DAY),'%y-%m-%d'),'0000-00-00');
		SET NEW.dismiss_arrival_date=0;
		IF OLD.date_to_ship_from_vendor>'0000-00-00' THEN
			SET @fair_warning_failed = (DATEDIFF(OLD.date_to_ship_from_vendor,NOW())<15);
		
			INSERT INTO po_ship_date_log SET ship_date=OLD.date_to_ship_from_vendor, po_id=OLD.id, fair_warning_failed=@fair_warning_failed,audit_created_by=CONCAT('po trigger');
		END IF;
	END IF;
	
	IF NEW.arrival_date THEN
		IF OLD.arrival_date<>'0000-00-00' AND OLD.arrival_date<>NEW.arrival_date THEN
			SET NEW.old_arrival_date = OLD.arrival_date;
		END IF;	
	END IF;	
}
AFTER INSERT {
	INSERT INTO main_search SET action_id=NEW.id,search_value=NEW.id,search_type="po",store_id=0 ,audit_created_by=CONCAT('po trigger');
}
AFTER DELETE {
	DELETE FROM main_search WHERE action_id=OLD.id;
}
DEF:orders_details_dropships
AFTER INSERT {
	SET @dropship_count = (SELECT COUNT(*) FROM orders_details_dropships WHERE order_detail_id=NEW.order_detail_id);
	UPDATE orders_details SET dropship_count=@dropship_count WHERE id=NEW.order_detail_id;
}
AFTER DELETE {
	SET @dropship_count = (SELECT COUNT(*) FROM orders_details_dropships WHERE order_detail_id=OLD.order_detail_id);
	UPDATE orders_details SET dropship_count=@dropship_count WHERE id=OLD.order_detail_id;
}
DEF:m_store
BEFORE INSERT {
	/*audit_sql*/
	
}
BEFORE UPDATE {
	/*audit_sql*/
	
	IF NEW.store_website IS NOT NULL THEN
		IF OLD.store_website<>NEW.store_website THEN
			SET NEW.reprocess_watermarked_images=1;
		END IF;
	END IF;
    IF old.account_status <> NEW.account_status AND NEW.account_status = 0 THEN
    	SET NEW.on_hold_date = NOW();
    END IF;

}
AFTER INSERT {
	INSERT INTO main_search SET search_value=NEW.id, action_id=NEW.id, search_type="profile",store_id=NEW.id ,audit_created_by=CONCAT('m_store trigger');
	INSERT INTO main_search SET search_value=NEW.store_name, action_id=NEW.id, search_type="profile_name",store_id=NEW.id ,audit_created_by=CONCAT('m_store trigger');
}
AFTER UPDATE {
	IF NEW.store_name THEN
		IF NEW.store_name<>OLD.store_name THEN
			UPDATE main_search SET search_value=NEW.store_name WHERE action_id=NEW.id AND search_type="profile_name";
		END IF;
		IF NEW.account_status<>OLD.account_status THEN
                        UPDATE main_search SET search_value=NEW.store_name WHERE action_id=NEW.id AND search_type="profile_name";
		END IF;

	END IF;
}
AFTER DELETE {
	DELETE FROM main_search WHERE action_id=OLD.id;
}

DEF:payments_log
AFTER INSERT {
	IF NEW.invoice_id > 0 THEN 
		IF NEW.credit_amount>0 THEN
			IF @credit_notes IS NULL THEN
				SET @credit_notes = CONCAT('Extra $ from payment on invoice ',NEW.invoice_id);
			END IF;
			IF IFNULL(@dont_autocredit_ondelete,0)=0 THEN
				INSERT INTO credits SET payment_id=NEW.id, invoice_id=NEW.invoice_id,store_id=NEW.store_id, amount=NEW.credit_amount, used_amount=0, notes=@credit_notes,audit_created_by=CONCAT('payments_log trigger');
			END IF;
		END IF;
	ELSE 
		IF NEW.credit_id = 0 THEN
			INSERT INTO credits SET payment_id=NEW.id, invoice_id=0,store_id=NEW.store_id, amount=NEW.credit_amount, used_amount=0, notes=CONCAT('Advanced payment'),audit_created_by=CONCAT('payments_log trigger');
		END IF;
	END IF;
	
	SET @total_payments = (SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM payments_log WHERE store_id=NEW.store_id)
								UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHERE (SELECT store_id FROM invoice WHERE id=invoice_id)=NEW.store_id)
								UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE store_id=NEW.store_id AND payment_method_id>5)) AS tbl);
								
	SET @balance = (SELECT SUM(grand_total) FROM invoice WHERE store_id=NEW.store_id)-@total_payments;
	UPDATE m_store SET store_balance=@balance WHERE id=NEW.store_id;
	
	IF NEW.credit_id THEN 
		SET @credit_used_amount = (SELECT SUM(ABS(amount)+ABS(credit_amount)) FROM payments_log WHERE credit_id=NEW.credit_id);	
		UPDATE credits SET used_amount=@credit_used_amount WHERE id=NEW.credit_id;
	END IF;
	
	IF NEW.invoice_id IS NOT NULL THEN 
		/*SET @total_payments = IFNULL((SELECT SUM(ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) FROM payments_log WHERE invoice_id=NEW.invoice_id),0)+IFNULL((SELECT SUM(ABS(payment_amount)*IF(payment_type<=5,1,-1)) FROM invoice_payment WHERE invoice_id=NEW.invoice_id),0)-IFNULL((SELECT SUM(amount) FROM store_payments WHERE invoice_id=NEW.invoice_id AND payment_method_id>5),0);*/
		
		SET @total_payments = (SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM payments_log WHERE invoice_id=NEW.invoice_id)
								UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHERE invoice_id=NEW.invoice_id)
								UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE invoice_id=NEW.invoice_id AND payment_method_id>5)) AS tbl);

		UPDATE invoice SET grand_total_cancel=@total_payments WHERE id=NEW.invoice_id;
		
		
		SET @total_for_invoice = IFNULL((SELECT SUM(invoiced_qty*(invoice_sell_price-(IF(discount_type=0,(invoice_sell_price)*((discount/100)),discount)))) FROM invoice_details WHERE invoice_id=NEW.invoice_id),0);
		UPDATE invoice SET grand_total=IFNULL(IF(store_address_id>0,0,IFNULL(drop_ship_fee,0))+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+IF(overall_discount_type=0, @total_for_invoice * (1-(overall_discount/100)), @total_for_invoice-overall_discount),0), net_total=IFNULL(@total_for_invoice,0) WHERE id=NEW.invoice_id;
		
		
	END IF;
}
BEFORE INSERT {
	/*audit_sql*/
	
	IF (SELECT operation_type FROM m_payment_method WHERE id=NEW.payment_type)='debit' THEN 
		IF NEW.invoice_id > 0 THEN 
			SET @invoice_total = IFNULL((SELECT grand_total FROM invoice WHERE id=NEW.invoice_id),0);
			SET @payments_total = IFNULL((SELECT grand_total_cancel FROM invoice WHERE id=NEW.invoice_id),0);
			
			
			IF ABS(@payments_total + NEW.amount) > @invoice_total THEN
				SET @new_amount = (@invoice_total - ABS(@payments_total));
				SET @credits = ABS(NEW.amount)-@new_amount;
				
				SET NEW.amount=@new_amount;
				SET NEW.credit_amount = @credits;
			END IF;
		ELSE
			IF NEW.credit_id=0 THEN
				SET NEW.credit_amount = NEW.amount;
				SET NEW.amount=0;
			END IF;
		END IF;
	END IF;
}
AFTER DELETE {
	SET @total_payments = (SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM payments_log WHERE store_id=OLD.store_id)
								UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHERE (SELECT store_id FROM invoice WHERE id=invoice_id)=OLD.store_id)
								UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE store_id=OLD.store_id AND payment_method_id>5)) AS tbl);
								
	SET @balance = (SELECT SUM(grand_total) FROM invoice WHERE store_id=OLD.store_id)-@total_payments;
	UPDATE m_store SET store_balance=@balance WHERE id=OLD.store_id;
	
	IF OLD.invoice_id IS NOT NULL THEN 
		/*SET @total_payments = IFNULL((SELECT SUM(ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) FROM payments_log WHERE invoice_id=OLD.invoice_id),0)+IFNULL((SELECT SUM(ABS(payment_amount)*IF(payment_type<=5,1,-1)) FROM invoice_payment WHERE invoice_id=OLD.invoice_id),0)-IFNULL((SELECT SUM(amount) FROM store_payments WHERE invoice_id=OLD.invoice_id AND payment_method_id>5),0);*/
		
		SET @total_payments = (SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM payments_log WHERE invoice_id=OLD.invoice_id)
								UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHERE invoice_id=OLD.invoice_id)
								UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE invoice_id=OLD.invoice_id AND payment_method_id>5)) AS tbl);
								
		UPDATE invoice SET grand_total_cancel=@total_payments WHERE id=OLD.invoice_id;
		
		SET @total_for_invoice = IFNULL((SELECT SUM(invoiced_qty*(invoice_sell_price-(IF(discount_type=0,(invoice_sell_price)*((discount/100)),discount)))) FROM invoice_details WHERE invoice_id=OLD.invoice_id),0);
		UPDATE invoice SET grand_total=IFNULL(IF(store_address_id>0,0,IFNULL(drop_ship_fee,0))+IFNULL(other_charges,0)+IFNULL(shipping_charges,0)+IF(overall_discount_type=0, @total_for_invoice * (1-(overall_discount/100)), @total_for_invoice-overall_discount),0), net_total=IFNULL(@total_for_invoice,0) WHERE id=OLD.invoice_id;
		
		
	END IF;
}
DEF:factory_payments
BEFORE INSERT {
	/*audit_sql*/
	
	SET @owe_total = (SELECT (grand_total-payments_total) FROM factory_invoice WHERE id=NEW.factory_invoice_id);
	SET @payments_for_invoice = (SELECT payments_total FROM factory_invoice WHERE id=NEW.factory_invoice_id);

	IF NEW.amount>@owe_total THEN
		SET @factory_deposit = NEW.amount - @owe_total;
		SET @vendor_id = (SELECT vendor_id FROM factory_invoice WHERE id=NEW.factory_invoice_id);
		
		SET NEW.amount = NEW.amount - @factory_deposit;
		
		INSERT INTO factory_deposits SET vendor_id=@vendor_id, deposit_amount=@factory_deposit, used_amount=0,wire_details=NEW.wire_details,audit_created_by=CONCAT('factory_paymens trigger');
		
	END IF;
}
AFTER INSERT {
	SET @payments_total = (SELECT SUM(amount) FROM factory_payments WHERE factory_invoice_id=NEW.factory_invoice_id);
	UPDATE factory_invoice SET payments_total=@payments_total WHERE id=NEW.factory_invoice_id;
	
	IF NEW.deposit_id THEN 
		SET @used_from_deposit = (SELECT SUM(amount) FROM factory_payments WHERE deposit_id=NEW.deposit_id);
		UPDATE factory_deposits SET used_amount=@used_from_deposit WHERE id=NEW.deposit_id;
	END IF;
}
AFTER UPDATE {
	SET @payments_total = (SELECT SUM(amount) FROM factory_payments WHERE factory_invoice_id=NEW.factory_invoice_id);
	UPDATE factory_invoice SET payments_total=@payments_total WHERE id=NEW.factory_invoice_id;
	
	IF NEW.deposit_id THEN 
		SET @used_from_deposit = (SELECT SUM(amount) FROM factory_payments WHERE deposit_id=NEW.deposit_id);
		UPDATE factory_deposits SET used_amount=@used_from_deposit WHERE id=NEW.deposit_id;
	END IF;
}
AFTER DELETE {
	SET @payments_total = (SELECT SUM(amount) FROM factory_payments WHERE factory_invoice_id=OLD.factory_invoice_id);
	UPDATE factory_invoice SET payments_total=@payments_total WHERE id=OLD.factory_invoice_id;
	
	IF OLD.deposit_id THEN 
		SET @used_from_deposit = (SELECT SUM(amount) FROM factory_payments WHERE deposit_id=OLD.deposit_id);
		UPDATE factory_deposits SET used_amount=@used_from_deposit WHERE id=OLD.deposit_id;
	END IF;
}
DEF:packingslip
AFTER INSERT {
	INSERT INTO factory_invoice SET vendor_id=NEW.vendor_id,packinglist_id=NEW.id,audit_created_by=CONCAT('packingslip trigger');
	
	INSERT INTO main_search SET search_value=NEW.id, action_id=NEW.id, search_type="packing",store_id=0, audit_created_by=CONCAT('packingslip trigger');
	
	INSERT INTO watches_log SET packingslip_id=NEW.id, `m_watches_id`=9, audit_created_by=CONCAT('packingslip trigger');
}
AFTER UPDATE {
	IF IFNULL(NEW.tracking_number,'')<>'' THEN
		IF OLD.tracking_number<>NEW.tracking_number THEN
			UPDATE main_search SET search_value=NEW.tracking_number WHERE action_id=NEW.id AND search_type="tracking";
			
			UPDATE orders_details SET status_id=10,status_history=CONCAT('packing',',',NEW.id,',',@app_username) WHERE IFNULL(alloted_qty,0)<qty AND po_detail_id IN (SELECT po_detail_id FROM packingslip_details WHERE packingslip_id=NEW.id);
		
			UPDATE po SET yet_to_ship=((SELECT SUM(qty) FROM po_detail WHERE po_id=po.id)-(SELECT SUM(qty) FROM packingslip_details WHERE (SELECT po_id FROM po_detail WHERE id=po_detail_id)=po.id AND (SELECT tracking_number FROM packingslip WHERE id=packingslip_id)<>'')), audit_updated_by=CONCAT('packingslip trigger') WHERE (SELECT COUNT(*) FROM po_detail WHERE po_id=po.id AND id IN (SELECT po_detail_id FROM packingslip_details WHERE packingslip_id=NEW.id))>0;
			
		END IF;
	END IF;
}
AFTER DELETE {
	DELETE FROM main_search WHERE action_id=OLD.id;
}
BEFORE UPDATE {
	/*audit_sql*/
	
	IF IFNULL(NEW.tracking_number,'')<>'' THEN
		SET @total_items_in_packing = IFNULL((SELECT SUM(qty) FROM packingslip_details WHERE packingslip_id=OLD.id),0);
		IF @total_items_in_packing=0 THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'There are no items in this packing list. Please add items before entering the tracking number';
		END IF;
		
		IF(IFNULL(NEW.tracking_number,'')<>IFNULL(OLD.tracking_number,'')) THEN
			/* status 2 = tracking number assigned*/
			SET NEW.`status`=2;
			/* if packing have tracking number then it is not editable*/ 
			SET @invoice_id = (SELECT id FROM factory_invoice WHERE packinglist_id = OLD.id);
			UPDATE factory_invoice SET locked=1 WHERE id = @invoice_id;
			/* watches log for*/
			SET @total_qty = IFNULL((SELECT SUM(qty) FROM packingslip_details WHERE packingslip_id=OLD.id),0);
			INSERT INTO watches_log SET packingslip_id=OLD.id, qty=@total_qty, m_watches_id=1,audit_created_by=CONCAT('packingslip trigger');
		END IF;
	ELSE
		IF IFNULL(OLD.tracking_number,'')<>IFNULL(NEW.tracking_number,'') AND IFNULL(NEW.tracking_number,'')='' THEN
			SET NEW.`status`=0;
			SET @invoice_id = (SELECT id FROM factory_invoice WHERE packinglist_id = OLD.id);
			UPDATE factory_invoice SET locked=0 WHERE id = @invoice_id;
		END IF;
	END IF;
}
BEFORE INSERT {
	/*audit_sql*/

	IF IFNULL(NEW.tracking_number,'')<>'' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'There are no items in this packing list. Please add items before entering the tracking number';
	END IF;
}
DEF:packingslip_details
BEFORE INSERT {
	/*audit_sql*/
	
	SET @factory_locked = (SELECT `locked` FROM factory_invoice WHERE packinglist_id = NEW.packingslip_id);
		
	IF (@factory_locked>0) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Once tracking number is entered, no more changes are allowed to the packing list and factory invoice';
	END IF;
	
	SET @tracking = IFNULL((SELECT tracking_number FROM packingslip WHERE id=NEW.packingslip_id),'');	
	
	IF @tracking<>'' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Once tracking number is entered, no more changes are allowed to the packing list and factory invoice';	
	END IF;
	
	SET @po_qty = (SELECT qty FROM po_detail WHERE id = NEW.po_detail_id);
	SET @already_packed = IFNULL((SELECT SUM(qty) FROM packingslip_details WHERE po_detail_id=NEW.po_detail_id),0);
	
	IF (@already_packed+IFNULL(NEW.qty,0))>@po_qty THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You cannot pack more items than the PO qty';	
	END IF;
	
	SET NEW.style_name = IFNULL((SELECT style_name FROM po_detail WHERE id=NEW.po_detail_id),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM po_detail WHERE id=NEW.po_detail_id),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM po_detail WHERE   id=NEW.po_detail_id),'');
	SET NEW.factory_cost = NEW.qty * (SELECT cost_vendor_one+cost_material_price FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=(SELECT style_cs_id FROM po_detail WHERE id=NEW.po_detail_id)));
}

BEFORE UPDATE {
	/*audit_sql*/
	
	IF IFNULL(NEW.received_qty,0)=IFNULL(OLD.received_qty,0) AND NEW.audit_updated_by NOT LIKE '%trigger' THEN
			
		IF IFNULL(NEW.container_no,IFNULL(OLD.container_no,''))<>IFNULL(OLD.container_no,'') THEN
			SET @factory_locked = (SELECT `locked` FROM factory_invoice WHERE packinglist_id = NEW.packingslip_id);

			IF (@factory_locked>0) THEN
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Once tracking number is entered, no more changes are allowed to the packing list and factory invoice';
			END IF;
			
			SET @tracking = IFNULL((SELECT tracking_number FROM packingslip WHERE id=OLD.packingslip_id),'');	
			
			IF @tracking<>'' THEN
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Once tracking number is entered, no more changes are allowed to the packing list and factory invoice';	
			END IF;
		END IF;
		
		IF(NEW.qty <> OLD.qty) THEN
			SET NEW.factory_cost = NEW.qty * (SELECT cost_vendor_one+cost_material_price FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=(SELECT style_cs_id FROM po_detail WHERE id=OLD.po_detail_id)));
		END IF;

	END IF;

}

AFTER INSERT {
	SET @packed = IFNULL((SELECT SUM(qty) FROM packingslip_details WHERE po_detail_id=NEW.po_detail_id),0);
	UPDATE po_detail SET in_packed=@packed, audit_updated_by=CONCAT('packingslip_details trigger') WHERE id = NEW.po_detail_id;
	
	SET @packingslip_total = IFNULL((SELECT SUM(factory_cost) FROM packingslip_details WHERE packingslip_id=NEW.packingslip_id),0);
	SET @factory_invoice_items_total = IFNULL((SELECT SUM(amount) FROM factory_invoice_items WHERE factory_invoice_id=(SELECT id FROM factory_invoice WHERE packinglist_id=NEW.packingslip_id)),0);
	
	UPDATE factory_invoice SET grand_total=(@packingslip_total + @factory_invoice_items_total) WHERE packinglist_id=NEW.packingslip_id;
	
	SET @packing_total_qty = (SELECT SUM(qty) FROM packingslip_details WHERE packingslip_id=NEW.packingslip_id);
	SET @packing_total_received_qty = (SELECT SUM(LEAST(qty,received_qty)) FROM packingslip_details WHERE packingslip_id=NEW.packingslip_id);
	UPDATE packingslip SET total_qty=@packing_total_qty, total_received_qty=@packing_total_received_qty WHERE id=NEW.packingslip_id;
	
}
AFTER UPDATE {
	SET @packingslip_total = IFNULL((SELECT SUM(qty * (SELECT cost_vendor_one+cost_material_price FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=(SELECT style_cs_id FROM po_detail WHERE id=po_detail_id)))) FROM packingslip_details WHERE packingslip_id=NEW.packingslip_id),0);
	UPDATE factory_invoice SET grand_total=@packingslip_total WHERE packinglist_id=NEW.packingslip_id;
	
	/* if total qty is receive then change status to received*/
	SET @total_qty = IFNULL((SELECT SUM(qty) FROM packingslip_details WHERE packingslip_id = NEW.packingslip_id),0);
	SET @total_received = IFNULL((SELECT SUM(received_qty) FROM packingslip_details WHERE packingslip_id = NEW.packingslip_id),0);
	IF(@total_qty =@total_received) THEN
		UPDATE packingslip SET status=3 WHERE id = NEW.packingslip_id;
	END IF;
	
	SET @packing_total_qty = (SELECT SUM(qty) FROM packingslip_details WHERE packingslip_id=NEW.packingslip_id);
	SET @packing_total_received_qty = (SELECT SUM(LEAST(qty,received_qty)) FROM packingslip_details WHERE packingslip_id=NEW.packingslip_id);
	UPDATE packingslip SET total_qty=@packing_total_qty, total_received_qty=@packing_total_received_qty WHERE id=NEW.packingslip_id;	
}
AFTER DELETE {
	SET @packingslip_total = IFNULL((SELECT SUM(qty * (SELECT cost_vendor_one+cost_material_price FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=(SELECT style_cs_id FROM po_detail WHERE id=po_detail_id)))) FROM packingslip_details WHERE packingslip_id=OLD.packingslip_id),0);
	UPDATE factory_invoice SET grand_total=@packingslip_total WHERE packinglist_id=OLD.packingslip_id;
	
	
	SET @packed = IFNULL((SELECT SUM(qty) FROM packingslip_details WHERE po_detail_id=OLD.po_detail_id),0);
	UPDATE po_detail SET in_packed=@packed, audit_updated_by=CONCAT('packingslip_details trigger') WHERE id = OLD.po_detail_id;
	
	SET @packing_total_qty = (SELECT SUM(qty) FROM packingslip_details WHERE packingslip_id=OLD.packingslip_id);
	SET @packing_total_received_qty = (SELECT SUM(LEAST(qty,received_qty)) FROM packingslip_details WHERE packingslip_id=OLD.packingslip_id);
	UPDATE packingslip SET total_qty=@packing_total_qty, total_received_qty=@packing_total_received_qty WHERE id=OLD.packingslip_id;
}
BEFORE DELETE {
	/*audit_sql*/
	
	SET @tracking = IFNULL((SELECT tracking_number FROM packingslip WHERE id=OLD.packingslip_id),'');	
	
	IF @tracking<>'' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Once tracking number is entered, no more changes are allowed to the packing list and factory invoice';	
	END IF;
}
DEF:credits
BEFORE UPDATE {
	/*audit_sql*/
	
	IF ABS(IFNULL(NEW.used_amount,OLD.used_amount)) > ABS(OLD.amount) THEN
		SET @msg = CONCAT('You are trying to use more credit than what is available ');
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;
}
AFTER INSERT {
	SET @total_credits = (SELECT SUM(abs(amount)-abs(used_amount)) FROM credits WHERE store_id=NEW.store_id);
	UPDATE m_store SET store_credits=@total_credits WHERE id=NEW.store_id;
}
AFTER UPDATE {
	SET @total_credits = (SELECT SUM(abs(amount)-abs(used_amount)) FROM credits WHERE store_id=NEW.store_id);
	UPDATE m_store SET store_credits=@total_credits WHERE id=NEW.store_id;
}
DEF:returns
BEFORE INSERT {
	/*audit_sql*/
	
	SET @total_returned = IFNULL((SELECT SUM(qty) FROM `returns` WHERE invoice_details_id=NEW.invoice_details_id),0);
	SET @invoice_qty = (SELECT invoiced_qty FROM invoice_details WHERE id=NEW.invoice_details_id);
	
	IF NEW.qty>@invoice_qty THEN
		SET @msg = CONCAT('You are trying to return more items (',NEW.qty,') than the actual invoice (',@invoice_qty,')');
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;
	
	SET NEW.invoice_id = (SELECT invoice_id FROM invoice_details WHERE id=NEW.invoice_details_id);
	SET NEW.order_id = (SELECT (SELECT order_id FROM orders_details WHERE id=order_details_id) FROM invoice_details WHERE id=NEW.invoice_details_id);
}
AFTER INSERT {
	SET @order_detail_line = (SELECT order_details_id FROM invoice_details WHERE id=NEW.invoice_details_id);
	UPDATE orders_details SET returned_qty = returned_qty + NEW.qty WHERE id=@order_detail_line;
}
DEF:styles_image_manager
BEFORE INSERT {
	/*audit_sql*/
	SET NEW.position = (IFNULL((SELECT position FROM styles_image_manager WHERE style_id=new.style_id ORDER BY position DESC LIMIT 1),0)+1);
}
DEF:m_store_customerlogin_orderdetail
BEFORE INSERT {
	/*audit_sql*/
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
}
BEFORE UPDATE {
	/*audit_sql*/
	SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
	SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.style_cs_id)),'');
}
DEF:factory_invoice_items
BEFORE INSERT {
	/*audit_sql*/
	IF((SELECT `locked` FROM factory_invoice WHERE id=NEW.factory_invoice_id)>0) THEN
		SET @msg = CONCAT('This invoice can not be modified because the packing list already has tracking number.');
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;
}
AFTER INSERT {
	SET @packingslip_total = IFNULL((SELECT SUM(factory_cost) FROM packingslip_details WHERE packingslip_id=(SELECT packinglist_id FROM factory_invoice WHERE id=NEW.factory_invoice_id)),0);
	SET @factory_invoice_items_total = IFNULL((SELECT SUM(amount) FROM factory_invoice_items WHERE factory_invoice_id=NEW.factory_invoice_id),0);
	
	UPDATE factory_invoice SET grand_total=(@packingslip_total + @factory_invoice_items_total) WHERE id=NEW.factory_invoice_id;
}
AFTER DELETE {
	SET @packingslip_total = IFNULL((SELECT SUM(factory_cost) FROM packingslip_details WHERE packingslip_id=(SELECT packinglist_id FROM factory_invoice WHERE id=OLD.factory_invoice_id)),0);
	SET @factory_invoice_items_total = IFNULL((SELECT SUM(amount) FROM factory_invoice_items WHERE factory_invoice_id=OLD.factory_invoice_id),0);
	
	UPDATE factory_invoice SET grand_total=(@packingslip_total + @factory_invoice_items_total) WHERE id=OLD.factory_invoice_id;
}
DEF:deleted_orders_details
BEFORE INSERT{
	SET NEW.audit_updated_by = @app_username;
}
AFTER INSERT{
	
	/* watches_log for canceled items */
	SET @store_id = IFNULL((SELECT store_id FROM orders WHERE id=NEW.order_id),0);
	IF(NEW.order_id>0) THEN
		INSERT INTO watches_log SET `store_id`=@store_id, `order_id`=NEW.order_id , deleted_orders_details_id=NEW.id, `m_watches_id`=3, qty = NEW.qty,audit_created_by=CONCAT('deleted_orders_details trigger');
	END IF;
}
DEF:rush_requested_detail
BEFORE UPDATE{
	/*audit_sql*/
	IF (OLD.confirmed <> NEW.confirmed) AND (NEW.confirmed>0) THEN
		/* watches_log confirmed by factory */
		INSERT INTO `watches_log` SET `rush_requested_detail_id`=OLD.id, m_watches_id=7,audit_created_by=CONCAT('rush_requested_detail trigger');
	END IF;
}
DEF:invoice
AFTER INSERT {
	INSERT INTO main_search SET action_id=NEW.id, search_value=NEW.id, search_type="invoice",store_id=(SELECT store_id FROM invoice WHERE id=NEW.id),audit_created_by=CONCAT('invoice trigger');
	
	IF IFNULL(NEW.tracking_number,'')<>'' THEN
		UPDATE main_search SET search_value=NEW.tracking_number WHERE action_id=NEW.id AND search_type="invoice_tracking";
		
		UPDATE items_serial_master SET invoice_tracking_number_datetime=CURRENT_TIMESTAMP(), 
			invoice_tracking_number_user=@app_username WHERE invoice_details_id IN (SELECT id FROM invoice_details WHERE invoice_id=NEW.id);
	END IF;
}
BEFORE INSERT {
	/*audit_sql*/
	IF IFNULL(NEW.dropship_name,'')<>"" THEN
		SET NEW.drop_ship_fee=(SELECT dropship_fee FROM m_store WHERE id=NEW.store_id);
	END IF;
}
BEFORE UPDATE {
	/*audit_sql*/
	IF OLD.dropship_name<>NEW.dropship_name THEN
		IF IFNULL(NEW.dropship_name,"")<>"" THEN
			IF OLD.drop_ship_fee=0 THEN 
				SET NEW.drop_ship_fee=(SELECT dropship_fee FROM m_store WHERE id=NEW.store_id);
			END IF;
		ELSE 
			SET NEW.drop_ship_fee=0;
		END IF;
	END IF;
	/*
	SET @total_for_invoice = (SELECT SUM(invoice_sell_price*invoiced_qty-(IF(discount_type=0,(invoice_sell_price*invoiced_qty)*((discount/100)),discount))) FROM invoice_details WHERE invoice_id=NEW.id);
	SET NEW.grand_total=IFNULL(NEW.drop_ship_fee,OLD.drop_ship_fee)+IFNULL(NEW.other_charges,OLD.other_charges)+IFNULL(NEW.shipping_charges,OLD.shipping_charges)+IFNULL(@total_for_invoice,0);
	*/
	/*IF IFNULL(OLD.grand_total,0)=IFNULL(NEW.grand_total,0) THEN */
		SET @total_for_invoice = IFNULL((SELECT SUM(invoiced_qty*(invoice_sell_price-(IF(discount_type=0,(invoice_sell_price)*((discount/100)),discount)))) FROM invoice_details WHERE invoice_id=NEW.id),0);
		SET NEW.grand_total=IFNULL(IFNULL(IF(NEW.store_address_id>0,0,IFNULL(NEW.drop_ship_fee,OLD.drop_ship_fee)),0)+IFNULL(IFNULL(NEW.other_charges,OLD.other_charges),0)+IFNULL(IFNULL(NEW.shipping_charges,OLD.shipping_charges),0)+IF(IFNULL(NEW.overall_discount_type,OLD.overall_discount_type)=0, @total_for_invoice * (1-(IFNULL(NEW.overall_discount,OLD.overall_discount)/100)), @total_for_invoice-IFNULL(NEW.overall_discount,OLD.overall_discount)),0);
		SET NEW.net_total=IFNULL(@total_for_invoice,0);
	/*END IF;*/
	
	
	IF IFNULL(NEW.tracking_number,'') <> IFNULL(OLD.tracking_number,'') THEN
		SET NEW.ship_date = NOW();
		
		IF IFNULL(NEW.tracking_number,'')<>'' THEN
			SET NEW.ship_status="Shipped";
			/*UPDATE orders_details SET status_id=2,status_history=CONCAT('shipped',',',NEW.id,',',@app_username) WHERE id IN (SELECT order_details_id FROM invoice_details WHERE invoice_id=NEW.id);*/
		ELSE
			SET NEW.ship_status="Not Shipped";
			/*UPDATE orders_details SET status_id=5,status_history=CONCAT('unshipped',',',NEW.id,',',@app_username) WHERE id IN (SELECT order_details_id FROM invoice_details WHERE invoice_id=NEW.id);*/
		END IF;
	
	END IF;
	
	/* change invoice status */
	IF( (IFNULL(OLD.grand_total,0) <> IFNULL(NEW.grand_total,0)) OR (IFNULL(OLD.grand_total_cancel,0) <> IFNULL(NEW.grand_total_cancel,0)) ) THEN
	
		IF IFNULL(NEW.grand_total_cancel,0) >= IFNULL(NEW.grand_total,0) THEN
			SET NEW.invoice_status = 2; /*  Paid  */
		END IF;
		
		IF IFNULL(NEW.grand_total_cancel,0)=0 THEN
			SET NEW.invoice_status = 1; /*  Owing  */
		END IF;
		
		IF IFNULL(NEW.grand_total_cancel,0)>0 AND (IFNULL(NEW.grand_total_cancel,0) < IFNULL(NEW.grand_total,0)) THEN
			SET NEW.invoice_status = 3; /* Partly Paid */ 
		END IF;

	END IF ;

	IF IFNULL(NEW.tracking_number,'')<>'' THEN
		UPDATE main_search SET search_value=NEW.tracking_number WHERE action_id=NEW.id AND search_type="invoice_tracking";
		
		UPDATE items_serial_master SET invoice_tracking_number_datetime=CURRENT_TIMESTAMP(), 
			invoice_tracking_number_user=@app_username WHERE invoice_details_id IN (SELECT id FROM invoice_details WHERE invoice_id=NEW.id);
	END IF;

}
AFTER UPDATE {
	IF @dont_update_store_balance IS NULL OR @dont_update_store_balance=0 THEN
		SET @total_payments = (SELECT SUM(amount) FROM ((SELECT (ABS(amount)*IF((SELECT operation_type FROM m_payment_method WHERE id=payment_type)='debit',1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM payments_log WHERE store_id=NEW.store_id)
									UNION (SELECT (ABS(payment_amount)*IF(payment_type<=5,1,-1)) AS amount,audit_created_date,invoice_id,payment_type FROM invoice_payment WHERE (SELECT store_id FROM invoice WHERE id=invoice_id)=NEW.store_id)
									UNION (SELECT ABS(amount)*-1 AS amount,audit_created_date,invoice_id,payment_method_id AS payment_type FROM store_payments WHERE store_id=NEW.store_id AND payment_method_id>5)) AS tbl);
									
		SET @balance = (SELECT SUM(grand_total) FROM invoice WHERE store_id=NEW.store_id)-@total_payments;
		UPDATE m_store SET store_balance=@balance WHERE id=NEW.store_id;
	END IF;
}
AFTER DELETE {
	DELETE FROM main_search WHERE action_id=OLD.id;
}
DEF:styles
AFTER INSERT {
	INSERT INTO main_search SET action_id=NEW.id, search_value=NEW.name, search_type="style",store_id=0,audit_created_by=CONCAT('styles trigger');
}
AFTER UPDATE {
	IF IFNULL(NEW.name,'')<>'' THEN
		IF NEW.name<>OLD.name THEN
			UPDATE main_search SET search_value=NEW.name WHERE action_id=NEW.id;
		END IF;
	END IF;
}
AFTER DELETE {
	DELETE FROM main_search WHERE action_id=OLD.id;
}
DEF:m_user_screen_log
AFTER DELETE {
	INSERT INTO #dblog#.m_user_screen_log SET user_id=OLD.user_id, in_time=OLD.in_time, out_time=OLD.out_time, controller=OLD.controller, `action`=OLD.`action`, url=OLD.url, audit_created_date=OLD.audit_created_date,audit_created_by=OLD.audit_created_by, audit_updated_by=OLD.audit_updated_by, audit_updated_date=OLD.audit_updated_date, audit_ip=OLD.audit_ip;
}
DEF:styles_images_server_queueing
AFTER DELETE {
	IF OLD.callback_table="m_store_customerlogin_downloaded" THEN
		DELETE FROM m_store_customerlogin_downloaded WHERE imgserver_id=OLD.temp_uid;
	END IF;
}
DEF:items_serial_master
BEFORE INSERT {
	/*audit_sql*/
	IF IFNULL(NEW.styles_cs_id,0)<>0 THEN
		SET NEW.style_name = IFNULL((SELECT name FROM styles WHERE id=(SELECT style_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
		SET NEW.color_name = IFNULL((SELECT color_name FROM m_color WHERE id=(SELECT color_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
		SET NEW.size_name = IFNULL((SELECT size_name FROM m_size WHERE id=(SELECT size_id FROM styles_cs WHERE id=NEW.styles_cs_id)),'');
	END IF;
	IF IFNULL(NEW.po_detail_id,0)<>0 THEN
		SET NEW.po_created_datetime=CURRENT_TIMESTAMP();
		
		SET @po_id = (SELECT po_id FROM po_detail WHERE id=NEW.po_detail_id);
		
		SET NEW.po_id=@po_id;
		SET NEW.po_created_user=(SELECT audit_created_by FROM po WHERE id=@po_id);
	END IF;
}
BEFORE UPDATE {
	/*audit_sql*/
	IF IFNULL(NEW.invoice_details_id,0)<>0 THEN
		SET NEW.invoice_id = (SELECT invoice_id FROM invoice_details WHERE id=NEW.invoice_details_id);
		SET NEW.invoice_id_entered_date = CURRENT_TIMESTAMP();
		SET NEW.invoice_id_entered_user = @app_username;
	END IF;
	
	IF IFNULL(NEW.packingslip_details_id,0)<>0 THEN
		SET NEW.packingslip_id=(SELECT packingslip_id FROM packingslip_details WHERE id=NEW.packingslip_details_id);
		SET NEW.packingslip_id_entered_date = CURRENT_TIMESTAMP();
		SET NEW.packingslip_id_entered_user = @app_username;
	END IF;
	
	IF IFNULL(NEW.po_detail_id,0)<>0 THEN
		SET NEW.po_created_datetime=CURRENT_TIMESTAMP();
		
		SET @po_id = (SELECT po_id FROM po_detail WHERE id=NEW.po_detail_id);
		
		SET NEW.po_id=@po_id;
		SET NEW.po_created_user=(SELECT audit_created_by FROM po WHERE id=@po_id);
	END IF;
	
	IF IFNULL(NEW.epc_id_entered_date,0)<>0 THEN
		SET NEW.epc_id_entered_user = @app_username;
	END IF;
}

DEF:mm_styles_category_sortorder
AFTER INSERT {
	UPDATE link_styles_category SET `position`=NEW.sort_order WHERE mm_styles_category_id=NEW.category_id AND styles_id=NEW.style_id;
}
DEF:m_vendors
AFTER UPDATE{
	IF OLD.buffer_days <> NEW.buffer_days THEN
                UPDATE po SET arrival_date = IFNULL(DATE_FORMAT(DATE_ADD(date_to_ship_from_vendor,INTERVAL (NEW.buffer_days) DAY),'%y-%m-%d'),'0000-00-00'), dismiss_arrival_date = 0 WHERE vendor_id = NEW.id and yet_to_ship>0;
	END IF;
}
