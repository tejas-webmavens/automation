DEF:1customers
AFTER INSERT{
	INSERT INTO m_user_roles_assigned SET user_id=NEW.id, role_id=5;
}
DEF:2rfq_request
BEFORE INSERT{
	IF NEW.csr_user_id IS NOT NULL THEN
		SET NEW.csr_user_name = (SELECT username FROM m_users WHERE id=NEW.csr_user_id);
	END IF;
	IF NEW.sales_user_id IS NOT NULL THEN
		SET NEW.sales_user_name = (SELECT username FROM m_users WHERE id=NEW.sales_user_id);
	END IF;
	IF NEW.csr_user_id IS NOT NULL THEN
		SET NEW.csr_user_name = (SELECT username FROM m_users WHERE id=NEW.csr_user_id);
	END IF;
	IF NEW.sales_user_id IS NOT NULL THEN
		SET NEW.sales_user_name = (SELECT username FROM m_users WHERE id=NEW.sales_user_id);
	END IF;
}
AFTER UPDATE{
	IF NEW.quote_required_date<>OLD.quote_required_date THEN
		UPDATE 3rfq SET quote_required_date=NEW.quote_required_date WHERE rfq_request_id=NEW.id;
	END IF;
	IF NEW.priority<>OLD.priority THEN
        UPDATE 3rfq SET priority=NEW.priority WHERE rfq_request_id=NEW.id;
    END IF;
}
AFTER UPDATE{
	IF NEW.quote_required_date<>OLD.quote_required_date THEN
		UPDATE 3rfq SET quote_required_date=NEW.quote_required_date WHERE rfq_request_id=NEW.id;
	END IF;
	IF NEW.priority<>OLD.priority THEN
        UPDATE 3rfq SET priority=NEW.priority WHERE rfq_request_id=NEW.id;
    END IF;
}

DEF:3rfq
BEFORE INSERT{
	SET NEW.priority = (SELECT priority FROM 2rfq_request WHERE id=NEW.rfq_request_id);
	SET NEW.csr_user_id = (SELECT csr_user_id FROM 2rfq_request WHERE id=NEW.rfq_request_id);
	SET NEW.sales_user_id = (SELECT sales_user_id FROM 2rfq_request WHERE id=NEW.rfq_request_id);
	SET NEW.start_date = (SELECT CURDATE());
	SET NEW.customer_name = (SELECT company_name FROM 1customers INNER JOIN 2rfq_request ON 2rfq_request.customer_id=1customers.id WHERE 2rfq_request.id=NEW.rfq_request_id);
	IF NEW.manager_user_id IS NOT NULL THEN
		SET NEW.manager_user_name = (SELECT username FROM m_users WHERE id=NEW.manager_user_id);
	END IF;
	IF NEW.engineer_user_id IS NOT NULL THEN
		SET NEW.engineer_user_name = (SELECT username FROM m_users WHERE id=NEW.engineer_user_id);
	END IF;
	IF NEW.csr_user_id IS NOT NULL THEN
		SET NEW.csr_user_name = (SELECT username FROM m_users WHERE id=NEW.csr_user_id);
	END IF;
	IF NEW.sales_user_id IS NOT NULL THEN
		SET NEW.sales_user_name = (SELECT username FROM m_users WHERE id=NEW.sales_user_id);
	END IF;
	SET NEW.quote_required_date = (SELECT quote_required_date FROM 2rfq_request WHERE id=NEW.rfq_request_id);
}
BEFORE UPDATE{
	SET NEW.customer_name = (SELECT company_name FROM 1customers INNER JOIN 2rfq_request ON 2rfq_request.customer_id=1customers.id WHERE 2rfq_request.id=NEW.rfq_request_id);

	IF NEW.customer_accepted_nda=OLD.customer_accepted_nda THEN
		SET NEW.customer_accepted_nda_datetime = OLD.customer_accepted_nda_datetime;
		SET NEW.customer_accepted_nda_ip = OLD.customer_accepted_nda_ip;
	ELSE
		IF NEW.customer_accepted_nda=0 THEN
			SET NEW.customer_accepted_nda = 1;
			SET NEW.customer_accepted_nda_datetime = OLD.customer_accepted_nda_datetime;
			SET NEW.customer_accepted_nda_ip = OLD.customer_accepted_nda_ip;	
		END IF;
	END IF;

	IF NEW.customer_accepted_drawing_policy=OLD.customer_accepted_drawing_policy THEN
		SET NEW.customer_accepted_drawing_policy_datetime = OLD.customer_accepted_drawing_policy_datetime;
		SET NEW.customer_accepted_drawing_policy_ip = OLD.customer_accepted_drawing_policy_ip;
	ELSE
		IF NEW.customer_accepted_drawing_policy=0 THEN
			SET NEW.customer_accepted_drawing_policy=1;
			SET NEW.customer_accepted_drawing_policy_datetime = OLD.customer_accepted_drawing_policy_datetime;
			SET NEW.customer_accepted_drawing_policy_ip = OLD.customer_accepted_drawing_policy_ip;	
		END IF;
	END IF;

	IF NEW.customer_accepted_tac=OLD.customer_accepted_tac THEN
		SET NEW.customer_accepted_tac_datetime = OLD.customer_accepted_tac_datetime;
		SET NEW.customer_accepted_tac_ip = OLD.customer_accepted_tac_ip;
	ELSE
		IF NEW.customer_accepted_tac=0 THEN
			SET NEW.customer_accepted_tac=1;
			SET NEW.customer_accepted_tac_datetime = OLD.customer_accepted_tac_datetime;
			SET NEW.customer_accepted_tac_ip = OLD.customer_accepted_tac_ip;	
		END IF;
	END IF;

	IF NEW.manager_user_id IS NOT NULL AND OLD.manager_user_id<>NEW.manager_user_id THEN
		SET NEW.manager_user_name = (SELECT username FROM m_users WHERE id=NEW.manager_user_id);
	END IF;
	IF NEW.engineer_user_id IS NOT NULL AND OLD.engineer_user_id<>NEW.engineer_user_id THEN
		SET NEW.engineer_user_name = (SELECT username FROM m_users WHERE id=NEW.engineer_user_id);
	END IF;
	IF NEW.csr_user_id IS NOT NULL AND OLD.csr_user_id<>NEW.csr_user_id THEN
		SET NEW.csr_user_name = (SELECT username FROM m_users WHERE id=NEW.csr_user_id);
	END IF;
	IF NEW.sales_user_id IS NOT NULL AND OLD.sales_user_id<>NEW.sales_user_id THEN
		SET NEW.sales_user_name = (SELECT username FROM m_users WHERE id=NEW.sales_user_id);
	END IF;
}

DEF:3_1rfq_items
BEFORE INSERT{
	SET NEW.rfq_id = (SELECT id FROM 3rfq WHERE rfq_request_id=NEW.rfq_request_id);
	SET NEW.overall_progress_percentage = ((NEW.progress_dwg_percentage+NEW.progress_bom_percentage+NEW.progress_labor_percentage)/3);
}
BEFORE UPDATE{
	IF(OLD.progress_dwg_percentage<>NEW.progress_dwg_percentage OR OLD.progress_bom_percentage<>NEW.progress_bom_percentage OR OLD.progress_labor_percentage<>NEW.progress_labor_percentage) THEN
		SET NEW.overall_progress_percentage = ((NEW.progress_dwg_percentage+NEW.progress_bom_percentage+NEW.progress_labor_percentage)/3);
	END IF;
}
AFTER INSERT{
	SET @progress_dwg_percentage = (SELECT SUM(progress_dwg_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
	SET @progress_bom_percentage = (SELECT SUM(progress_bom_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
	SET @progress_labor_percentage = (SELECT SUM(progress_labor_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);

	SET @progress_dwg_percentage_count = (SELECT COUNT(progress_dwg_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
	SET @progress_bom_percentage_count = (SELECT COUNT(progress_bom_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
	SET @progress_labor_percentage_count = (SELECT COUNT(progress_labor_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);

	SET @progress_dwg_percentage_val = (@progress_dwg_percentage/@progress_dwg_percentage_count);
	SET @progress_bom_percentage_val = (@progress_bom_percentage/@progress_bom_percentage_count);
	SET @progress_labor_percentage_val = (@progress_labor_percentage/@progress_labor_percentage_count);
	SET @item_ids = (SELECT GROUP_CONCAT(item_id) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);

	UPDATE 3rfq SET progress_dwg_percentage=@progress_dwg_percentage_val, progress_bom_percentage=@progress_bom_percentage_val, progress_labor_percentage=@progress_labor_percentage_val, item_ids=@item_ids WHERE id=NEW.rfq_id;

	IF NEW.testing_upload_document<>'' THEN
		INSERT INTO 3_3rfq_items_attachments SET rfq_items_id=NEW.id, rfq_id=NEW.rfq_id, doc_description='Testing DOC', file_path=NEW.testing_upload_document, uploaded_by=NEW.audit_created_by, uploaded_timestamp=NEW.audit_created_date;
	END IF;

	IF NEW.bom_upload_document<>'' THEN
		INSERT INTO 3_3rfq_items_attachments SET rfq_items_id=NEW.id, rfq_id=NEW.rfq_id, doc_description='BOM DOC',file_path=NEW.bom_upload_document, uploaded_by=NEW.audit_created_by, uploaded_timestamp=NEW.audit_created_date;
	END IF;
}
AFTER UPDATE{
	IF (NEW.progress_dwg_percentage<>OLD.progress_dwg_percentage) THEN
		SET @progress_dwg_percentage = (SELECT SUM(progress_dwg_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
		SET @progress_dwg_percentage_count = (SELECT COUNT(progress_dwg_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
		SET @progress_dwg_percentage_val = (@progress_dwg_percentage/@progress_dwg_percentage_count);

		UPDATE 3rfq SET progress_dwg_percentage=@progress_dwg_percentage_val WHERE id=NEW.rfq_id;
	END IF;

	IF (NEW.progress_bom_percentage<>OLD.progress_bom_percentage) THEN
		SET @progress_bom_percentage = (SELECT SUM(progress_bom_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
		SET @progress_bom_percentage_count = (SELECT COUNT(progress_bom_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
		SET @progress_bom_percentage_val = (@progress_bom_percentage/@progress_bom_percentage_count);

		UPDATE 3rfq SET progress_bom_percentage=@progress_bom_percentage_val WHERE id=NEW.rfq_id;
	END IF;

	IF (NEW.progress_labor_percentage<>OLD.progress_labor_percentage) THEN
		SET @progress_labor_percentage = (SELECT SUM(progress_labor_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
		SET @progress_labor_percentage_count = (SELECT COUNT(progress_labor_percentage) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
		SET @progress_labor_percentage_val = (@progress_labor_percentage/@progress_labor_percentage_count);

		UPDATE 3rfq SET progress_labor_percentage=@progress_labor_percentage_val WHERE id=NEW.rfq_id;
	END IF;

	IF NEW.testing_upload_document<>'' AND OLD.testing_upload_document<>NEW.testing_upload_document THEN
		INSERT INTO 3_3rfq_items_attachments SET rfq_items_id=NEW.id, rfq_id=NEW.rfq_id, doc_description='Testing DOC', file_path=NEW.testing_upload_document, uploaded_by=NEW.audit_created_by, uploaded_timestamp=NEW.audit_created_date;
	END IF;

	IF NEW.bom_upload_document<>'' AND OLD.bom_upload_document<>NEW.bom_upload_document THEN
		INSERT INTO 3_3rfq_items_attachments SET rfq_items_id=NEW.id, rfq_id=NEW.rfq_id, doc_description='BOM DOC',file_path=NEW.bom_upload_document, uploaded_by=NEW.audit_created_by, uploaded_timestamp=NEW.audit_created_date;
	END IF;

	IF NEW.item_id<>OLD.item_id THEN
		SET @item_ids = (SELECT GROUP_CONCAT(item_id) FROM 3_1rfq_items WHERE rfq_id=NEW.rfq_id);
		UPDATE 3rfq SET item_ids=@item_ids WHERE id=NEW.rfq_id;
	END IF;
}

DEF:3_2rfq_items__qty
BEFORE INSERT{
	SET @total_material_value_with_margin = NEW.total_material_value*(1+(NEW.material_margin/100));
	SET @total_labor_cost_usa = NEW.total_labor_cost_usa*(1+(NEW.labor_margin_usa/100));
	SET @total_labor_cost_india = NEW.total_labor_cost_india*(1+(NEW.labor_margin_india/100));
	SET NEW.rfq_id = (SELECT rfq_id FROM 3_1rfq_items WHERE id=NEW.rfq_items_id);
	SET NEW.extended_value_price_usa = (@total_material_value_with_margin+(NEW.release_qty*@total_labor_cost_usa));
	SET NEW.extended_value_price_india = (@total_material_value_with_margin+(NEW.release_qty*@total_labor_cost_india));
	SET NEW.unit_price_sell_usa = (ROUND(NEW.extended_value_price_usa/NEW.release_qty, 2));
	SET NEW.unit_price_sell_india = (ROUND(NEW.extended_value_price_india/NEW.release_qty, 2));
	SET NEW.real_extended_value_price_usa = (NEW.unit_price_sell_usa*NEW.release_qty);
	SET NEW.real_extended_value_price_india = (NEW.unit_price_sell_india*NEW.release_qty);
}
BEFORE UPDATE{
	IF NEW.total_material_value<>OLD.total_material_value OR NEW.total_labor_cost_usa<>OLD.total_labor_cost_usa OR NEW.total_labor_cost_india<>OLD.total_labor_cost_india OR NEW.material_margin<>OLD.material_margin OR NEW.labor_margin_usa<>OLD.labor_margin_usa OR NEW.labor_margin_india<>OLD.labor_margin_india OR NEW.total_nre_tools_value<>OLD.total_nre_tools_value THEN
		SET @total_material_value_with_margin = NEW.total_material_value*(1+(NEW.material_margin/100));
		SET @total_labor_cost_usa = NEW.total_labor_cost_usa*(1+(NEW.labor_margin_usa/100));
		SET @total_labor_cost_india = NEW.total_labor_cost_india*(1+(NEW.labor_margin_india/100));
		SET NEW.extended_value_price_usa = (@total_material_value_with_margin+(NEW.release_qty*@total_labor_cost_usa));
		SET NEW.extended_value_price_india = (@total_material_value_with_margin+(NEW.release_qty*@total_labor_cost_india));
		SET NEW.unit_price_sell_usa = (ROUND(NEW.extended_value_price_usa/NEW.release_qty, 2));
		SET NEW.unit_price_sell_india = (ROUND(NEW.extended_value_price_india/NEW.release_qty, 2));
		SET NEW.real_extended_value_price_usa = (NEW.unit_price_sell_usa*NEW.release_qty);
		SET NEW.real_extended_value_price_india = (NEW.unit_price_sell_india*NEW.release_qty);
	END IF;

	/*IF(OLD.release_qty<>NEW.release_qty) THEN
		SET @msg=CONCAT("You can not update release quantity");
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;*/
}
BEFORE DELETE{
	SET @msg=CONCAT("You can not delete record");
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
}
AFTER INSERT{
	DECLARE rfq_items_release_qtys VARCHAR(255);
	SET rfq_items_release_qtys = (SELECT GROUP_CONCAT(release_qty) FROM 3_2rfq_items__qty WHERE rfq_items_id=NEW.rfq_items_id AND rfq_id=NEW.rfq_id);
	UPDATE 3_1rfq_items SET 3_1rfq_items.rfq_items_release_qtys=rfq_items_release_qtys;

	SET @avg_margin = (SELECT AVG(material_margin) FROM 3_2rfq_items__qty WHERE rfq_id=NEW.rfq_id );
	UPDATE 3rfq SET avg_margin=@avg_margin WHERE id = NEW.rfq_id;
}
AFTER UPDATE{
	DECLARE rfq_items_release_qtys VARCHAR(255);
	DECLARE row_count INT(11);
	SET rfq_items_release_qtys = (SELECT GROUP_CONCAT(release_qty) FROM 3_2rfq_items__qty WHERE rfq_items_id=NEW.rfq_items_id AND rfq_id=NEW.rfq_id);
	UPDATE 3_1rfq_items SET 3_1rfq_items.rfq_items_release_qtys=rfq_items_release_qtys;

	IF NEW.extended_value_price_usa <>OLD.extended_value_price_usa THEN
		SET @extended_value_price_max_usa = (SELECT SUM(T1.extended_value_price_usa) FROM (SELECT MAX(extended_value_price_usa) AS extended_value_price_usa FROM 3_2rfq_items__qty WHERE rfq_id=NEW.rfq_id GROUP BY rfq_items_id) T1);
		UPDATE 3rfq SET extended_value_price_max_usa=@extended_value_price_max_usa WHERE id=NEW.rfq_id;
	END IF;
	
	SET @avg_margin = (SELECT AVG(material_margin) FROM 3_2rfq_items__qty WHERE rfq_id=NEW.rfq_id );
	UPDATE 3rfq SET avg_margin=@avg_margin WHERE id = NEW.rfq_id;
}

DEF:4rfq_items_drawing
BEFORE INSERT{
	SET NEW.rfq_id = (SELECT rfq_id FROM 3_1rfq_items WHERE id=NEW.rfq_items_id);
	SET NEW.version_number = (SELECT IFNULL(MAX(version_number),0)+1 FROM 4rfq_items_drawing WHERE rfq_items_id=NEW.rfq_items_id);
}
AFTER INSERT{
	SET @default_rev = (SELECT COUNT(id) FROM 4rfq_items_drawing WHERE rfq_items_id=NEW.rfq_items_id AND default_rev=1);
	IF (@default_rev>0) THEN
		SET @drawing_per = 100;
	ELSE
		SET @row_count = (SELECT COUNT(id) FROM 4rfq_items_drawing WHERE rfq_items_id=NEW.rfq_items_id);
		IF(@row_count>0) THEN
			SET @drawing_per = 50;
		ELSE
			SET @drawing_per = 0;
		END IF;
	END IF;

	UPDATE 3_1rfq_items SET progress_dwg_percentage=@drawing_per WHERE id=NEW.rfq_items_id;

	INSERT INTO 3_3rfq_items_attachments SET rfq_items_id=NEW.rfq_items_id, rfq_id=NEW.rfq_id, doc_description='Item Drawing', file_path=NEW.drawing_file_path, uploaded_by=NEW.audit_created_by, uploaded_timestamp=NEW.audit_created_date;
}
AFTER UPDATE{
	IF(OLD.default_rev<>NEW.default_rev) THEN
		SET @default_rev = (SELECT COUNT(id) FROM 4rfq_items_drawing WHERE rfq_items_id=NEW.rfq_items_id AND default_rev=1);
		IF (@default_rev>0) THEN
			SET @drawing_per = 100;
		ELSE
			SET @row_count = (SELECT COUNT(id) FROM 4rfq_items_drawing WHERE rfq_items_id=NEW.rfq_items_id);
			IF(@row_count>0) THEN
				SET @drawing_per = 50;
			ELSE
				SET @drawing_per = 0;
			END IF;
		END IF;

		UPDATE 3_1rfq_items SET progress_dwg_percentage=@drawing_per WHERE id=NEW.rfq_items_id;
	END IF;

	IF NEW.drawing_file_path<>OLD.drawing_file_path AND NEW.drawing_file_path<>'' THEN
		INSERT INTO 3_3rfq_items_attachments SET rfq_items_id=NEW.rfq_items_id, rfq_id=NEW.rfq_id, doc_description='Item Drawing', file_path=NEW.drawing_file_path, uploaded_by=NEW.audit_created_by, uploaded_timestamp=NEW.audit_created_date;
	END IF;
}
AFTER DELETE{
	SET @default_rev = (SELECT COUNT(id) FROM 4rfq_items_drawing WHERE rfq_items_id=OLD.rfq_items_id AND default_rev=1);
	IF (@default_rev>0) THEN
		SET @drawing_per = 100;
	ELSE
		SET @row_count = (SELECT COUNT(id) FROM 4rfq_items_drawing WHERE rfq_items_id=OLD.rfq_items_id);
		IF(@row_count>0) THEN
			SET @drawing_per = 50;
		ELSE
			SET @drawing_per = 0;
		END IF;
	END IF;

	UPDATE 3_1rfq_items SET progress_dwg_percentage=@drawing_per WHERE id=OLD.rfq_items_id;
}

DEF:5rfq_items_bom
BEFORE INSERT{
	SET NEW.rfq_id = (SELECT rfq_id FROM 3_1rfq_items WHERE id=NEW.rfq_items_id);
	SET NEW.version_number = (SELECT IFNULL(MAX(version_number),0)+1 FROM 5rfq_items_bom WHERE rfq_items_id=NEW.rfq_items_id);
}
AFTER INSERT{

	SET @default_rev = (SELECT COUNT(id) FROM 5rfq_items_bom WHERE rfq_items_id=NEW.rfq_items_id AND default_rev=1);
	IF(@default_rev>0) THEN
		SET @bom_per = 100;
	ELSE
		SET @row_count = (SELECT COUNT(id) FROM 5rfq_items_bom WHERE rfq_items_id=NEW.rfq_items_id);
		IF(@row_count>0) THEN
			SET @bom_per = 50;
		ELSE
			SET @bom_per = 0;
		END IF;
	END IF;

	UPDATE 3_1rfq_items SET progress_bom_percentage=@bom_per WHERE id=NEW.rfq_items_id;

	IF (NEW.default_rev=1) THEN
		UPDATE 5_1rfq_items_bom_items SET active=1 WHERE rfq_items_bom_id=NEW.id;
	END IF;
}
AFTER UPDATE{

	SET @default_rev = (SELECT COUNT(id) FROM 5rfq_items_bom WHERE rfq_items_id=NEW.rfq_items_id AND default_rev=1);
	IF(@default_rev>0) THEN
		SET @bom_per = 100;
	ELSE
		SET @row_count = (SELECT COUNT(id) FROM 5rfq_items_bom WHERE rfq_items_id=NEW.rfq_items_id);
		IF(@row_count>0) THEN
			SET @bom_per = 50;
		ELSE
			SET @bom_per = 0;
		END IF;
	END IF;

	UPDATE 3_1rfq_items SET progress_bom_percentage=@bom_per WHERE id=NEW.rfq_items_id;

	IF (NEW.default_rev<>OLD.default_rev) THEN
		UPDATE 5_1rfq_items_bom_items SET active=NEW.default_rev WHERE rfq_items_bom_id=NEW.id;
	END IF;
}
AFTER DELETE{
	SET @default_rev = (SELECT COUNT(id) FROM 5rfq_items_bom WHERE rfq_items_id=OLD.rfq_items_id AND default_rev=1);
	IF(@default_rev>0) THEN
		SET @bom_per = 100;
	ELSE
		SET @row_count = (SELECT COUNT(id) FROM 5rfq_items_bom WHERE rfq_items_id=OLD.rfq_items_id);
		IF(@row_count>0) THEN
			SET @bom_per = 50;
		ELSE
			SET @bom_per = 0;
		END IF;
	END IF;

	UPDATE 3_1rfq_items SET progress_bom_percentage=@bom_per WHERE id=OLD.rfq_items_id;
}

DEF:5_1rfq_items_bom_items
BEFORE INSERT{
	SET NEW.rfq_id = (SELECT rfq_id FROM 5rfq_items_bom WHERE id=NEW.rfq_items_bom_id);
	SET @rfq_items_bom_id = NEW.rfq_items_bom_id;
	SET @rfq_id = NEW.rfq_id;
	SET @item_no = NEW.item_no;
	IF NEW.rfq_items_bom_items_id IS NULL THEN
		SET @rfq_items_bom_items_id = 0;
	ELSE
		SET @rfq_items_bom_items_id = NEW.rfq_items_bom_items_id;
	END IF;

	SET @check_same_item_avail = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id AND rfq_id=@rfq_id AND item_no=@item_no AND IFNULL(rfq_items_bom_items_id, 0)=@rfq_items_bom_items_id);
	IF @check_same_item_avail>0 THEN
		SET @msg=CONCAT("Duplicate entry for item no");
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;

	SET NEW.active = (SELECT default_rev  FROM 5rfq_items_bom WHERE id=NEW.rfq_items_bom_id);
	IF NEW.rfq_items_bom_items_id<>'' THEN
		SET @check_same_bom = (SELECT rfq_items_bom_id FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
		IF(@check_same_bom<>NEW.rfq_items_bom_id) THEN
			SET @msg=CONCAT("Parent and child items BOM id should be same");
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
		END IF;
	END IF;
}
BEFORE UPDATE{

	IF (NEW.rfq_items_bom_items_id<>OLD.rfq_items_bom_items_id) THEN
		IF NEW.rfq_items_bom_items_id<>'' THEN
			SET @check_same_bom = (SELECT rfq_items_bom_id FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			IF(@check_same_bom<>NEW.rfq_items_bom_id) THEN
				SET @msg=CONCAT("Parent and child items BOM id should be same");
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
			END IF;
			IF NEW.qty<>OLD.qty THEN
				CALL calculate_required_qty(NEW.rfq_items_bom_items_id, @parent_qty);
				SET @parent_qty_count = @parent_qty*NEW.qty;
				UPDATE 5_1rfq_items_bom_items_parent_count SET parent_qty_count=@parent_qty_count WHERE 5_1rfq_items_bom_items_id=NEW.id;
			END IF;
		ELSE
			IF NEW.qty<>OLD.qty THEN
				SET @parent_qty_count = NEW.qty;
				UPDATE 5_1rfq_items_bom_items_parent_count SET parent_qty_count=@parent_qty_count WHERE 5_1rfq_items_bom_items_id=NEW.id;
			END IF;
		END IF;
	END IF;

	IF (NEW.item_no<>OLD.item_no) THEN
		SET @msg=CONCAT("You can not change item number");
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;
}
BEFORE DELETE{
	CALL remove_from_required_qty(OLD.id);
	CALL remove_junk_consolidated_bom(OLD.rfq_id);
	IF(OLD.active=1) THEN
		CALL update_child_consolidated_data(OLD.id);
	END IF;
}
AFTER INSERT{
	DECLARE avail_row INT(1);
	DECLARE rfq_items_bom_items_ids_var VARCHAR(100);
	DECLARE item_no_var VARCHAR(255);
	DECLARE master_item_count INT(1);
	DECLARE master_item_no_var VARCHAR(100);
	DECLARE consolidated_count INT(10);

	DECLARE rfq_id_tmp INT(11);
	DECLARE item_no_tmp VARCHAR(255);
	DECLARE item_desc_tmp VARCHAR(255);
	DECLARE mfg_partnumber_tmp VARCHAR(255);
	DECLARE rev_tmp VARCHAR(5);
	DECLARE equivalent_tmp TINYINT(1);
	DECLARE uom_tmp VARCHAR(255);
	DECLARE note_tmp VARCHAR(255);
	DECLARE qty_tmp INT(1);

	DECLARE check_item_avail VARCHAR(255);
	DECLARE moq_var INT(11);

	IF NEW.rfq_items_bom_items_id<>'' THEN
		CALL calculate_required_qty(NEW.rfq_items_bom_items_id, @parent_qty);
		SET @parent_qty_count = @parent_qty*NEW.qty;
		INSERT INTO 5_1rfq_items_bom_items_parent_count SET 5_1rfq_items_bom_items_id=NEW.id, parent_qty_count=@parent_qty_count, rfq_id=NEW.rfq_id, rfq_items_bom_id=NEW.rfq_items_bom_id;
	ELSE
		SET @parent_qty_count = NEW.qty;
		INSERT INTO 5_1rfq_items_bom_items_parent_count SET 5_1rfq_items_bom_items_id=NEW.id, parent_qty_count=@parent_qty_count, rfq_id=NEW.rfq_id, rfq_items_bom_id=NEW.rfq_items_bom_id;
	END IF;

	IF(NEW.active=1) THEN
		IF(NEW.rfq_items_bom_items_id<>'') THEN
			SET rfq_id_tmp = (SELECT rfq_id FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET item_no_tmp = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET item_desc_tmp = (SELECT item_desc FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET mfg_partnumber_tmp = (SELECT mfg_part_number FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET rev_tmp = (SELECT rev FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET equivalent_tmp = (SELECT equivalent FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET uom_tmp = (SELECT uom FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET note_tmp = (SELECT note FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET qty_tmp = (SELECT qty FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET @part_class = (SELECT part_class FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);

			SET item_no_var = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET master_item_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE item_no=item_no_var AND active=1);
			IF(master_item_count=1) THEN
				DELETE FROM 5_1_1rfq_consolidated_bom WHERE item_no=item_no_var;
			ELSE
				SET master_item_no_var = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id AND rfq_id=NEW.rfq_id);
				-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
				SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
				SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
				UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=rfq_id_tmp, item_desc=item_desc_tmp, mfg_partnumber=mfg_partnumber_tmp, part_class=@part_class, rev=rev_tmp, equivalent=equivalent_tmp, uom=uom_tmp, note=note_tmp, inbound_freight=NEW.inbound_freight WHERE item_no=item_no_tmp AND rfq_id=NEW.rfq_id;
			END IF;
		END IF;

		SET avail_row = (SELECT COUNT(id) AS avail_row FROM 5_1_1rfq_consolidated_bom WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id);
		IF(avail_row>0) THEN
			-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
			SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
			SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
			UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=NEW.rfq_id, item_no=NEW.item_no, item_desc=NEW.item_desc, mfg_partnumber=NEW.mfg_part_number, part_class=NEW.part_class, rev=NEW.rev, equivalent=NEW.equivalent, uom=NEW.uom, note=NEW.note, inbound_freight=NEW.inbound_freight WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id;
		ELSE
			SET check_item_avail = (SELECT id FROM erp1_items WHERE ItemID=NEW.item_no AND AcctStatusFlag<>'0');
			IF check_item_avail IS NULL THEN
				SET moq_var = 1;
				SET @lead_time_in_days = 0;
			ELSE
				SET moq_var = (SELECT MinOrderQty FROM erp1_items WHERE id=check_item_avail AND AcctStatusFlag<>'0');
				SET @lead_time_in_days = (SELECT PurLeadTime FROM erp1_items WHERE id=check_item_avail AND AcctStatusFlag<>'0');
			END IF;

			SET consolidated_count = (SELECT parent_qty_count FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id=NEW.id);
			INSERT INTO 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=NEW.id, quantity_for_one_piece=consolidated_count, rfq_id=NEW.rfq_id, item_no=NEW.item_no, item_desc=NEW.item_desc, mfg_partnumber=NEW.mfg_part_number, part_class=NEW.part_class, rev=NEW.rev, equivalent=NEW.equivalent, uom=NEW.uom, note=NEW.note, moq=moq_var, inbound_freight=NEW.inbound_freight, lead_time_in_days=@lead_time_in_days;
		END IF;

	END IF;

	SET @rfq_consolidated_bom_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND rfq_items_bom_items_ids IN (NEW.id));
	SET @max_release_group = (SELECT MAX(release_group) FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_id=NEW.rfq_id AND rfq_consolidated_bom_id=@rfq_consolidated_bom_id);
	SET @count = 1;
	WHILE (@count<=@max_release_group) DO
		SET @rfq_items_bom_id = NEW.rfq_items_bom_id;
		SET @ids = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id);
		SET @id_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id);
		SET @internal_count = 0;
		SET @total_material_value = 0;

		SET @rfq_items_id = (SELECT rfq_items_id FROM 5rfq_items_bom WHERE id=NEW.rfq_items_bom_id);
		SET @release_qty = (SELECT release_qty FROM 3_2rfq_items__qty WHERE rfq_id=NEW.rfq_id AND release_group=@count AND rfq_items_id=@rfq_items_id);
		IF @release_qty IS NULL THEN
			SET @release_qty = 0;
		END IF;
		DO_THIS:
		LOOP
			SET @sub_total = 0;
			SET @internal_count = @internal_count+1;
			SET @id = SUBSTRING_INDEX(@ids, ',', 1);
			SET @consolidated_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE FIND_IN_SET(@id, rfq_items_bom_items_ids));
			SET @marked_price = (SELECT marked_price_calculate FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_id=NEW.rfq_id AND rfq_consolidated_bom_id=@consolidated_id AND release_group=@count);

			SET @qty = (SELECT qty FROM 5_1rfq_items_bom_items WHERE id IN(@id));
			SET @sub_total = (@release_qty*@marked_price*@qty);
			SET @total_material_value = (@total_material_value + @sub_total);
			SET @ids = (REPLACE(@ids, CONCAT(SUBSTRING_INDEX(@ids, ',', 1), ','), ''));
			IF (@internal_count >= @id_count) THEN
				LEAVE DO_THIS;
			END IF;
		END LOOP DO_THIS;
		
		UPDATE 3_2rfq_items__qty SET total_material_value=@total_material_value WHERE rfq_id=NEW.rfq_id AND rfq_items_id=@rfq_items_id AND release_group=@count;
		SET @count = @count+1;
	END WHILE;
}
AFTER UPDATE{
	DECLARE avail_row INT(1);
	DECLARE rfq_items_bom_items_ids_var VARCHAR(100);
	DECLARE item_count INT(1);
	DECLARE item_no_var VARCHAR(255);
	DECLARE master_item_count INT(1);
	DECLARE master_item_no_var VARCHAR(100);
	DECLARE consolidated_count INT(10);

	DECLARE rfq_id_tmp INT(11);
	DECLARE item_no_tmp VARCHAR(255);
	DECLARE item_desc_tmp VARCHAR(255);
	DECLARE mfg_partnumber_tmp VARCHAR(255);
	DECLARE rev_tmp VARCHAR(5);
	DECLARE equivalent_tmp TINYINT(1);
	DECLARE uom_tmp VARCHAR(255);
	DECLARE note_tmp VARCHAR(255);
	DECLARE qty_tmp INT(1);

	DECLARE m_rfq_id_tmp INT(11);
	DECLARE m_item_no_tmp VARCHAR(255);
	DECLARE m_item_desc_tmp VARCHAR(255);
	DECLARE m_mfg_partnumber_tmp VARCHAR(255);
	DECLARE m_rev_tmp VARCHAR(5);
	DECLARE m_equivalent_tmp TINYINT(1);
	DECLARE m_uom_tmp VARCHAR(255);
	DECLARE m_note_tmp VARCHAR(255);
	DECLARE m_qty_tmp INT(1);

	DECLARE new_master_item_no VARCHAR(100);
	DECLARE old_master_item_no VARCHAR(100);

	IF NEW.qty<>OLD.qty THEN
		IF NEW.rfq_items_bom_items_id<>'' THEN
			CALL calculate_required_qty(NEW.rfq_items_bom_items_id, @parent_qty);
			SET @parent_qty_count = @parent_qty*NEW.qty;
			UPDATE 5_1rfq_items_bom_items_parent_count SET parent_qty_count=@parent_qty_count WHERE 5_1rfq_items_bom_items_id=NEW.id;
		ELSE
			SET @parent_qty_count = NEW.qty;
			UPDATE 5_1rfq_items_bom_items_parent_count SET parent_qty_count=@parent_qty_count WHERE 5_1rfq_items_bom_items_id=NEW.id;
		END IF;
	END IF;

	SET @child_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_items_id=NEW.id);
	IF @child_count>0 THEN
		SET @child_ids = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_items_id=NEW.id);
		SET @qtys = (SELECT group_concat(qty) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_items_id=NEW.id);
		SET @internal_count = 0;
		DO_THIS2:
		LOOP
			SET @internal_count = @internal_count+1;
			SET @id = SUBSTRING_INDEX(@child_ids, ',', 1);
			SET @child_ids = (REPLACE(@child_ids, CONCAT(SUBSTRING_INDEX(@child_ids, ',', 1), ','), ''));
			SET @qty = SUBSTRING_INDEX(@qtys, ',', 1);
			SET @qtys = (REPLACE(@child_ids, CONCAT(SUBSTRING_INDEX(@qtys, ',', 1), ','), ''));
			CALL calculate_required_qty(@id, @parent_qty);
			SET @parent_qty_count = @parent_qty;
			UPDATE 5_1rfq_items_bom_items_parent_count SET parent_qty_count=@parent_qty_count WHERE 5_1rfq_items_bom_items_id=@id;

			IF (@internal_count >= @child_count) THEN
				LEAVE DO_THIS2;
			END IF;
		END LOOP DO_THIS2;
	END IF;

	IF(NEW.active<>OLD.active) THEN
		IF(NEW.active=0) THEN
			SET @active_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id);
			IF(@active_count=0) THEN
				DELETE FROM 5_1_1rfq_consolidated_bom WHERE rfq_id=NEW.rfq_id AND item_no=NEW.item_no;
			ELSE
				SET @avail_row = (SELECT COUNT(id) AS avail_row FROM 5_1_1rfq_consolidated_bom WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id);
				IF(@avail_row>0) THEN
					-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
					SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
					SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
					UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=NEW.rfq_id, item_no=NEW.item_no, item_desc=NEW.item_desc, mfg_partnumber=NEW.mfg_part_number, part_class=NEW.part_class, rev=NEW.rev, equivalent=NEW.equivalent, uom=NEW.uom, note=NEW.note, inbound_freight=NEW.inbound_freight WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id;
				ELSE
					IF(NEW.active<>0) THEN
						SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
						INSERT INTO 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=NEW.id, quantity_for_one_piece=consolidated_count, rfq_id=NEW.rfq_id, item_no=NEW.item_no, item_desc=NEW.item_desc, mfg_partnumber=NEW.mfg_part_number, part_class=NEW.part_class, rev=NEW.rev, equivalent=NEW.equivalent, uom=NEW.uom, note=NEW.note, inbound_freight=NEW.inbound_freight;
					END IF;
				END IF;
			END IF;
		ELSE
			SET @avail_row = (SELECT COUNT(id) AS avail_row FROM 5_1_1rfq_consolidated_bom WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id);
			IF(@avail_row>0) THEN
				-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
				SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
				SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
				UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=NEW.rfq_id, item_no=NEW.item_no, item_desc=NEW.item_desc, mfg_partnumber=NEW.mfg_part_number, part_class=NEW.part_class, rev=NEW.rev, equivalent=NEW.equivalent, uom=NEW.uom, note=NEW.note, inbound_freight=NEW.inbound_freight WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id;
			ELSE
				IF(NEW.active<>0) THEN
					SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
					INSERT INTO 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=NEW.id, quantity_for_one_piece=consolidated_count, rfq_id=NEW.rfq_id, item_no=NEW.item_no, item_desc=NEW.item_desc, mfg_partnumber=NEW.mfg_part_number, part_class=NEW.part_class, rev=NEW.rev, equivalent=NEW.equivalent, uom=NEW.uom, note=NEW.note, inbound_freight=NEW.inbound_freight;
				END IF;
			END IF;
		END IF;

		IF NEW.qty<>OLD.qty THEN
			SET @rfq_consolidated_bom_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND rfq_items_bom_items_ids IN (NEW.id));
			SET @max_release_group = (SELECT MAX(release_group) FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_id=NEW.rfq_id AND rfq_consolidated_bom_id=@rfq_consolidated_bom_id);
			SET @count = 1;
			WHILE (@count<=@max_release_group) DO
				SET @rfq_items_bom_id = NEW.rfq_items_bom_id;
				SET @ids = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id);
				SET @id_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id);
				SET @internal_count = 0;
				SET @total_material_value = 0;

				SET @rfq_items_id = (SELECT rfq_items_id FROM 5rfq_items_bom WHERE id=NEW.rfq_items_bom_id);
				SET @release_qty = (SELECT release_qty FROM 3_2rfq_items__qty WHERE rfq_id=NEW.rfq_id AND release_group=@count AND rfq_items_id=@rfq_items_id);
				IF @release_qty IS NULL THEN
					SET @release_qty = 0;
				END IF;
				DO_THIS1:
				LOOP
					SET @sub_total = 0;
					SET @internal_count = @internal_count+1;
					SET @id = SUBSTRING_INDEX(@ids, ',', 1);
					SET @consolidated_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE FIND_IN_SET(@id, rfq_items_bom_items_ids));
					SET @marked_price = (SELECT marked_price_calculate FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_id=NEW.rfq_id AND rfq_consolidated_bom_id=@consolidated_id AND release_group=@count);

					SET @qty = (SELECT qty FROM 5_1rfq_items_bom_items WHERE id IN(@id));
					SET @sub_total = (@release_qty*@marked_price*@qty);
					SET @total_material_value = (@total_material_value + @sub_total);
					SET @ids = (REPLACE(@ids, CONCAT(SUBSTRING_INDEX(@ids, ',', 1), ','), ''));
					IF (@internal_count >= @id_count) THEN
						LEAVE DO_THIS1;
					END IF;
				END LOOP DO_THIS1;
				
				UPDATE 3_2rfq_items__qty SET total_material_value=@total_material_value WHERE rfq_id=NEW.rfq_id AND rfq_items_id=@rfq_items_id AND release_group=@count;
				SET @count = @count+1;
			END WHILE;
		END IF;
	ELSE
		IF(NEW.rfq_items_bom_items_id<>OLD.rfq_items_bom_items_id) THEN

			SET rfq_id_tmp = (SELECT rfq_id FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET item_no_tmp = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET item_desc_tmp = (SELECT item_desc FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET mfg_partnumber_tmp = (SELECT mfg_part_number FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET rev_tmp = (SELECT rev FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET equivalent_tmp = (SELECT equivalent FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET uom_tmp = (SELECT uom FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET note_tmp = (SELECT note FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET qty_tmp = (SELECT qty FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
			SET @part_class_tmp = (SELECT part_class FROM 5_1rfq_items_bom_items WHERE id=NEW.part_class);

			IF(OLD.rfq_items_bom_items_id<>'') THEN

				SET old_master_item_no = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id AND rfq_id=NEW.rfq_id);
				SET new_master_item_no = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id AND rfq_id=NEW.rfq_id);

				IF(old_master_item_no<>new_master_item_no) THEN
					SET master_item_no_var = old_master_item_no;
					SET master_item_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var);

					IF(master_item_count=1) THEN

						SET m_rfq_id_tmp = (SELECT rfq_id FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET m_item_no_tmp = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET m_item_desc_tmp = (SELECT item_desc FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET m_mfg_partnumber_tmp = (SELECT mfg_part_number FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET m_rev_tmp = (SELECT rev FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET m_equivalent_tmp = (SELECT equivalent FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET m_uom_tmp = (SELECT uom FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET m_note_tmp = (SELECT note FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET m_qty_tmp = (SELECT qty FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
						SET @m_part_class_tmp = (SELECT part_class FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);

						IF(NEW.active<>0) THEN
							INSERT INTO 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=OLD.rfq_items_bom_items_id, quantity_for_one_piece=m_qty_tmp, rfq_id=m_rfq_id_tmp, item_no=m_item_no_tmp, item_desc=m_item_desc_tmp, mfg_partnumber=m_mfg_partnumber_tmp, part_class=@m_part_class_tmp, rev=m_rev_tmp, equivalent=m_equivalent_tmp, uom=m_uom_tmp, note=m_note_tmp, inbound_freight=NEW.inbound_freight;
						END IF;

					ELSE
						-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
						SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
						SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
						UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=rfq_id_tmp, item_desc=item_desc_tmp, mfg_partnumber=mfg_partnumber_tmp, part_class=@part_class_tmp, rev=rev_tmp, equivalent=equivalent_tmp, uom=uom_tmp, note=note_tmp, inbound_freight=NEW.inbound_freight WHERE item_no=master_item_no_var AND rfq_id=NEW.rfq_id;				
					END IF;
				END IF;

			END IF;

			IF(NEW.rfq_items_bom_items_id<>'') THEN
				SET master_item_no_var = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id AND active=1 AND rfq_id=NEW.rfq_id);
				SET master_item_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id);

				IF(master_item_count=1) THEN
					DELETE FROM 5_1_1rfq_consolidated_bom WHERE item_no=master_item_no_var;
				ELSE
					-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND active=1 AND rfq_items_bom_items_id<>''));
					SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
					SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND active=1 AND rfq_items_bom_items_id<>''));
					UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=rfq_id_tmp, item_desc=item_desc_tmp, mfg_partnumber=mfg_partnumber_tmp, part_class=@part_class_tmp, rev=rev_tmp, equivalent=equivalent_tmp, uom=uom_tmp, note=note_tmp WHERE item_no=item_no_tmp AND rfq_id=NEW.rfq_id;				
				END IF;
			ELSE
				SET item_no_var = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id);
				SET item_count = (SELECT COUNT(id) FROM 5_1_1rfq_consolidated_bom WHERE item_no=item_no_var);
				IF(item_count=0) THEN
					IF(NEW.active<>0) THEN
						SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
						INSERT INTO 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=NEW.rfq_items_bom_items_id, quantity_for_one_piece=consolidated_count, rfq_id=rfq_id_tmp, item_no=item_no_tmp, item_desc=item_desc_tmp, mfg_partnumber=mfg_partnumber_tmp, part_class=@part_class_tmp, rev=rev_tmp, equivalent=equivalent_tmp, uom=uom_tmp, note=note_tmp;
					END IF;
				ELSE
					SET master_item_no_var = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=NEW.rfq_items_bom_items_id AND active=1 AND rfq_id=NEW.rfq_id);
					-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
					SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
					SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
					UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=rfq_id_tmp, item_desc=item_desc_tmp, mfg_partnumber=mfg_partnumber_tmp, part_class=@part_class_tmp, rev=rev_tmp, equivalent=equivalent_tmp, uom=uom_tmp, note=note_tmp WHERE item_no=item_no_tmp AND rfq_id=NEW.rfq_id;
				END IF;
			END IF;
			
		END IF;

		SET avail_row = (SELECT COUNT(id) AS avail_row FROM 5_1_1rfq_consolidated_bom WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id);
		IF(avail_row>0) THEN
			-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
			SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
			SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''));
			UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=NEW.rfq_id, item_no=NEW.item_no, item_desc=NEW.item_desc, mfg_partnumber=NEW.mfg_part_number, part_class=NEW.part_class, rev=NEW.rev, equivalent=NEW.equivalent, uom=NEW.uom, note=NEW.note, inbound_freight=NEW.inbound_freight WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id;
		ELSE
			SET @master_item_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND active=1 AND rfq_items_bom_items_id=NEW.id);
			IF(NEW.active<>0 AND @master_item_count=0) THEN
				SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
				INSERT INTO 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=NEW.id, quantity_for_one_piece=consolidated_count, rfq_id=NEW.rfq_id, item_no=NEW.item_no, item_desc=NEW.item_desc, mfg_partnumber=NEW.mfg_part_number, part_class=NEW.part_class, rev=NEW.rev, equivalent=NEW.equivalent, uom=NEW.uom, note=NEW.note, inbound_freight=NEW.inbound_freight;
			END IF;
		END IF;

		IF NEW.qty<>OLD.qty THEN
			SET @rfq_consolidated_bom_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND rfq_items_bom_items_ids IN (NEW.id));
			SET @max_release_group = (SELECT MAX(release_group) FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_id=NEW.rfq_id AND rfq_consolidated_bom_id=@rfq_consolidated_bom_id);
			SET @count = 1;
			WHILE (@count<=@max_release_group) DO
				SET @rfq_items_bom_id = NEW.rfq_items_bom_id;
				SET @ids = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id);
				SET @id_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id);
				SET @internal_count = 0;
				SET @total_material_value = 0;

				SET @rfq_items_id = (SELECT rfq_items_id FROM 5rfq_items_bom WHERE id=NEW.rfq_items_bom_id);
				SET @release_qty = (SELECT release_qty FROM 3_2rfq_items__qty WHERE rfq_id=NEW.rfq_id AND release_group=@count AND rfq_items_id=@rfq_items_id);
				DO_THIS:
				LOOP
					SET @sub_total = 0;
					SET @internal_count = @internal_count+1;
					SET @id = SUBSTRING_INDEX(@ids, ',', 1);
					SET @consolidated_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE FIND_IN_SET(@id, rfq_items_bom_items_ids));
					SET @marked_price = (SELECT marked_price_calculate FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_id=NEW.rfq_id AND rfq_consolidated_bom_id=@consolidated_id AND release_group=@count);

					SET @qty = (SELECT qty FROM 5_1rfq_items_bom_items WHERE id IN(@id));
					SET @sub_total = (@release_qty*@marked_price*@qty);
					SET @total_material_value = (@total_material_value + @sub_total);
					SET @ids = (REPLACE(@ids, CONCAT(SUBSTRING_INDEX(@ids, ',', 1), ','), ''));
					IF (@internal_count >= @id_count) THEN
						LEAVE DO_THIS;
					END IF;
				END LOOP DO_THIS;

				UPDATE 3_2rfq_items__qty SET total_material_value=@total_material_value WHERE rfq_id=NEW.rfq_id AND rfq_items_id=@rfq_items_id AND release_group=@count;
				SET @count = @count+1;
			END WHILE;
		END IF;
	END IF;

	IF NEW.active=1 THEN
		IF NEW.part_class<>OLD.part_class AND OLD.part_class='Other' THEN
			SET @rfq_consolidated_bom_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND rfq_items_bom_items_ids IN (NEW.id));
			UPDATE 5_1_1_1rfq_consolidated_bom_costing SET source_type_auto='erp1', source_type_manual=NULL WHERE rfq_id=NEW.rfq_id AND rfq_consolidated_bom_id=@rfq_consolidated_bom_id;
		END IF;
	END IF;
}
AFTER DELETE{
	DECLARE avail_row INT(1);
	DECLARE rfq_items_bom_items_ids_var VARCHAR(100);
	DECLARE item_no_var VARCHAR(100);
	DECLARE item_count INT(1);
	DECLARE master_item_count INT(1);
	DECLARE master_item_no_var VARCHAR(100);
	DECLARE consolidated_count INT(10);

	DECLARE rfq_id_tmp INT(11);
	DECLARE item_no_tmp VARCHAR(255);
	DECLARE item_desc_tmp VARCHAR(255);
	DECLARE mfg_partnumber_tmp VARCHAR(255);
	DECLARE rev_tmp VARCHAR(5);
	DECLARE equivalent_tmp TINYINT(1);
	DECLARE uom_tmp VARCHAR(255);
	DECLARE note_tmp VARCHAR(255);
	DECLARE qty_tmp INT(1);

	DELETE FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id=OLD.id;
	IF(OLD.active=1) THEN
		IF(OLD.rfq_items_bom_items_id<>'') THEN
			SET item_no_var = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET item_count = (SELECT COUNT(id) FROM 5_1_1rfq_consolidated_bom WHERE item_no=item_no_var AND rfq_id=OLD.rfq_id);

			SET rfq_id_tmp = (SELECT rfq_id FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET item_no_tmp = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET item_desc_tmp = (SELECT item_desc FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET mfg_partnumber_tmp = (SELECT mfg_part_number FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET rev_tmp = (SELECT rev FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET equivalent_tmp = (SELECT equivalent FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET uom_tmp = (SELECT uom FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET note_tmp = (SELECT note FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET qty_tmp = (SELECT qty FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			SET @part_class_tmp = (SELECT part_class FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id);
			-- SET qty_tmp = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND active=1 AND rfq_id=NEW.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));

			IF(item_count=0) THEN
				SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=OLD.item_no AND active=1 AND rfq_id=OLD.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=OLD.rfq_id AND rfq_items_bom_items_id<>''))));
				INSERT INTO 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=OLD.rfq_items_bom_items_id, quantity_for_one_piece=qty_tmp, rfq_id=rfq_id_tmp, item_no=item_no_tmp, item_desc=item_desc_tmp, mfg_partnumber=mfg_partnumber_tmp, part_class=@part_class_tmp, rev=rev_tmp, equivalent=equivalent_tmp, uom=uom_tmp, note=note_tmp;
			ELSE
				SET master_item_no_var = (SELECT item_no FROM 5_1rfq_items_bom_items WHERE id=OLD.rfq_items_bom_items_id AND rfq_id=OLD.rfq_id);
				-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=OLD.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=OLD.rfq_id AND rfq_items_bom_items_id<>''));
				SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=OLD.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=OLD.rfq_id AND rfq_items_bom_items_id<>''))));
				SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=master_item_no_var AND active=1 AND rfq_id=OLD.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=OLD.rfq_id AND rfq_items_bom_items_id<>''));
				
				UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=OLD.rfq_id, item_desc=item_desc_tmp, mfg_partnumber=mfg_partnumber_tmp, part_class=@part_class_tmp, rev=rev_tmp, equivalent=equivalent_tmp, uom=uom_tmp, note=note_tmp WHERE item_no=OLD.item_no AND rfq_id=OLD.rfq_id;
			END IF;
		END IF;

		SET avail_row = (SELECT COUNT(id) AS avail_row FROM 5_1_1rfq_consolidated_bom WHERE item_no=OLD.item_no AND rfq_id=OLD.rfq_id);
		IF(avail_row>0) THEN
			-- SET consolidated_count = (SELECT IFNULL(SUM(qty),0) FROM 5_1rfq_items_bom_items WHERE item_no=OLD.item_no AND active=1 AND rfq_id=OLD.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=OLD.rfq_id AND rfq_items_bom_items_id<>''));
			SET consolidated_count = (SELECT IFNULL(SUM(parent_qty_count), 0) FROM 5_1rfq_items_bom_items_parent_count WHERE 5_1rfq_items_bom_items_id IN ((SELECT id FROM 5_1rfq_items_bom_items WHERE item_no=OLD.item_no AND active=1 AND rfq_id=OLD.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=OLD.rfq_id AND rfq_items_bom_items_id<>'' AND active=1))));
			IF(consolidated_count=0) THEN
				DELETE FROM 5_1_1rfq_consolidated_bom WHERE item_no=OLD.item_no AND rfq_id=OLD.rfq_id;
			ELSE
				SET rfq_items_bom_items_ids_var = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=OLD.item_no AND active=1 AND rfq_id=OLD.rfq_id AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=OLD.rfq_id AND rfq_items_bom_items_id<>''));
				UPDATE 5_1_1rfq_consolidated_bom SET rfq_items_bom_items_ids=rfq_items_bom_items_ids_var, quantity_for_one_piece=consolidated_count, rfq_id=OLD.rfq_id, item_no=OLD.item_no, item_desc=OLD.item_desc, mfg_partnumber=OLD.mfg_part_number, part_class=OLD.part_class, rev=OLD.rev, equivalent=OLD.equivalent, uom=OLD.uom, note=OLD.note WHERE item_no=OLD.item_no AND rfq_id=OLD.rfq_id;
			END IF;
		END IF;

		SET @rfq_consolidated_bom_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE item_no=OLD.item_no AND rfq_id=OLD.rfq_id AND rfq_items_bom_items_ids IN (OLD.id));
		SET @max_release_group = (SELECT MAX(release_group) FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_id=OLD.rfq_id AND rfq_consolidated_bom_id=@rfq_consolidated_bom_id);
		SET @count = 1;
		WHILE (@count<=@max_release_group) DO
			SET @rfq_items_bom_id = OLD.rfq_items_bom_id;
			SET @ids = (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id);
			SET @id_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE rfq_items_bom_id=@rfq_items_bom_id);
			SET @internal_count = 0;
			SET @total_material_value = 0;

			SET @rfq_items_id = (SELECT rfq_items_id FROM 5rfq_items_bom WHERE id=OLD.rfq_items_bom_id);
			SET @release_qty = (SELECT release_qty FROM 3_2rfq_items__qty WHERE rfq_id=OLD.rfq_id AND release_group=@count AND rfq_items_id=@rfq_items_id);
			DO_THIS:
			LOOP
				SET @sub_total = 0;
				SET @internal_count = @internal_count+1;
				SET @id = SUBSTRING_INDEX(@ids, ',', 1);
				SET @consolidated_id = (SELECT id FROM 5_1_1rfq_consolidated_bom WHERE FIND_IN_SET(@id, rfq_items_bom_items_ids));
				SET @marked_price = (SELECT marked_price_calculate FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_id=OLD.rfq_id AND rfq_consolidated_bom_id=@consolidated_id AND release_group=@count);

				SET @qty = (SELECT qty FROM 5_1rfq_items_bom_items WHERE id IN(@id));
				SET @sub_total = (@release_qty*@marked_price*@qty);
				SET @total_material_value = (@total_material_value + @sub_total);
				SET @ids = (REPLACE(@ids, CONCAT(SUBSTRING_INDEX(@ids, ',', 1), ','), ''));
				IF (@internal_count >= @id_count) THEN
					LEAVE DO_THIS;
				END IF;
			END LOOP DO_THIS;
			
			UPDATE 3_2rfq_items__qty SET total_material_value=@total_material_value WHERE rfq_id=OLD.rfq_id AND rfq_items_id=@rfq_items_id AND release_group=@count;
			SET @count = @count+1;
		END WHILE;
	END IF;
}

DEF:5_1_1rfq_consolidated_bom
BEFORE INSERT{
	DECLARE max_release_group INT(11);
	DECLARE release_qtys_var VARCHAR(50);
	DECLARE rfq_items_ids_var VARCHAR(50);
	DECLARE check_item_avail VARCHAR(255);
	DECLARE sum_of_release_qty INT(11);
	DECLARE total_req_qty INT(11);

	SET NEW.main_assembly = (SELECT group_concat(item_name) AS main_assembly FROM 3_1rfq_items WHERE FIND_IN_SET(id,(SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET(id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, NEW.rfq_items_bom_items_ids))))));

	SET @release_group_count = 1;
	SET max_release_group = (SELECT MAX(release_group) FROM 3_2rfq_items__qty WHERE rfq_id = NEW.rfq_id);

	WHILE (@release_group_count<=max_release_group) DO
		SET release_qtys_var = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
		SET rfq_items_ids_var = (SELECT group_concat(rfq_items_id ORDER BY rfq_items_id) AS rfq_items_ids FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
		IF release_qtys_var IS NOT NULL THEN
			SET sum_of_release_qty = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			SET @one_item_count = (SELECT group_concat(T1.parent_count) FROM (SELECT SUM(parent_qty_count) AS parent_count FROM 5_1rfq_items_bom_items_parent_count WHERE FIND_IN_SET(5_1rfq_items_bom_items_id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))) GROUP BY rfq_items_bom_id) T1);
			SET @temp_count = (SELECT COUNT(DISTINCT(rfq_items_bom_id)) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
			SET @count = 0;
			SET total_req_qty = 0;
			IF @temp_count>0 THEN
			DO_THIS:
			LOOP
				SET @count = @count+1;
				SET @set_one_pc_qty = SUBSTRING_INDEX(@one_item_count, ',', 1);
				SET @set_item_qty = SUBSTRING_INDEX(sum_of_release_qty, ',', 1);
				IF @set_one_pc_qty IS NULL THEN
					SET @set_one_pc_qty = 0;
				END IF;
				IF @set_item_qty IS NULL THEN
					SET @set_item_qty = 0;
				END IF;

				SET total_req_qty = total_req_qty + (@set_one_pc_qty * @set_item_qty);
				SET @one_item_count = (REPLACE(@one_item_count, CONCAT(SUBSTRING_INDEX(@one_item_count, ',', 1), ','), ''));
				SET @sum_of_release_qty = (REPLACE(@sum_of_release_qty, CONCAT(SUBSTRING_INDEX(@sum_of_release_qty, ',', 1), ','), ''));
				IF (@count >= @temp_count) THEN
					LEAVE DO_THIS;
				END IF;
			END LOOP DO_THIS;
			END IF;

			SET @get_item_id = (SELECT id FROM erp1_items WHERE ItemID=NEW.item_no AND AcctStatusFlag<>'0');
			IF @get_item_id IS NOT NULL THEN
				SET @get_GLInvAcctNbr = (SELECT GLInvAcctNbr FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
				IF @get_GLInvAcctNbr='1004.9' OR @get_GLInvAcctNbr='1004.2' THEN
					SET @lead_time_in_days = (SELECT PurLeadTime FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
					SET @moq = (SELECT MinOrderQty FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
				ELSEIF NEW.part_class='Other' THEN
					SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
					IF @check_qty_avail=0 THEN
						SET @lead_time_in_days = 0;
						SET @moq = 1;
					ELSE
						SET @lead_time_in_days = (SELECT PurLeadTime FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
						SET @moq = (SELECT MinOrderQty FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
					END IF;
				ELSE
					SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
					IF @check_qty_avail=0 THEN
						SET @lead_time_in_days = 0;
						SET @moq = 1;
					ELSE
						SET @lead_time_in_days = (SELECT PurLeadTime FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
						SET @moq = (SELECT MinOrderQty FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
					END IF;
				END IF;
			ELSE
				SET @lead_time_in_days = 0;
				SET @moq = 1;
			END IF;
		END IF;
		SET @release_group_count = @release_group_count + 1;
	END WHILE;

	SET NEW.lead_time_in_days = @lead_time_in_days;
	SET NEW.moq = @moq;
}
BEFORE UPDATE{
	DECLARE max_release_group INT(11);
	DECLARE release_qtys_var VARCHAR(50);
	DECLARE rfq_items_ids_var VARCHAR(50);
	DECLARE check_item_avail VARCHAR(255);
	DECLARE sum_of_release_qty INT(11);
	DECLARE total_req_qty INT(11);
	
	IF(NEW.rfq_items_bom_items_ids<>OLD.rfq_items_bom_items_ids) THEN
		SET NEW.main_assembly = (SELECT group_concat(item_name) AS main_assembly FROM 3_1rfq_items WHERE FIND_IN_SET(id,(SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET(id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, NEW.rfq_items_bom_items_ids))))));
	END IF;

	SET @release_group_count = 1;
	SET max_release_group = (SELECT MAX(release_group) FROM 3_2rfq_items__qty WHERE rfq_id = NEW.rfq_id);
	SET @is_manual = (SELECT COUNT(id) FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_consolidated_bom_id=NEW.id AND ((IFNULL(source_type_manual,'')<>'' AND source_type_manual='manual') OR (IFNULL(source_type_manual,'')='' AND source_type_auto='manual')));
	IF @is_manual=0 THEN
		WHILE (@release_group_count<=max_release_group) DO
			SET release_qtys_var = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			SET rfq_items_ids_var = (SELECT group_concat(rfq_items_id ORDER BY rfq_items_id) AS rfq_items_ids FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			IF release_qtys_var IS NOT NULL THEN
				SET sum_of_release_qty = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
				SET @one_item_count = (SELECT group_concat(T1.parent_count) FROM (SELECT SUM(parent_qty_count) AS parent_count FROM 5_1rfq_items_bom_items_parent_count WHERE FIND_IN_SET(5_1rfq_items_bom_items_id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))) GROUP BY rfq_items_bom_id) T1);
				SET @temp_count = (SELECT COUNT(DISTINCT(rfq_items_bom_id)) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
				SET @count = 0;
				SET total_req_qty = 0;
				IF @temp_count>0 THEN
				DO_THIS:
				LOOP
					SET @count = @count+1;
					SET @set_one_pc_qty = SUBSTRING_INDEX(@one_item_count, ',', 1);
					SET @set_item_qty = SUBSTRING_INDEX(sum_of_release_qty, ',', 1);
					IF @set_one_pc_qty IS NULL THEN
						SET @set_one_pc_qty = 0;
					END IF;
					IF @set_item_qty IS NULL THEN
						SET @set_item_qty = 0;
					END IF;

					SET total_req_qty = total_req_qty + (@set_one_pc_qty * @set_item_qty);
					SET @one_item_count = (REPLACE(@one_item_count, CONCAT(SUBSTRING_INDEX(@one_item_count, ',', 1), ','), ''));
					SET @sum_of_release_qty = (REPLACE(@sum_of_release_qty, CONCAT(SUBSTRING_INDEX(@sum_of_release_qty, ',', 1), ','), ''));
					IF (@count >= @temp_count) THEN
						LEAVE DO_THIS;
					END IF;
				END LOOP DO_THIS;
				END IF;

				SET @get_item_id = (SELECT id FROM erp1_items WHERE ItemID=NEW.item_no AND AcctStatusFlag<>'0');
				IF @get_item_id IS NOT NULL THEN
					SET @get_GLInvAcctNbr = (SELECT GLInvAcctNbr FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
					IF @get_GLInvAcctNbr='1004.9' OR @get_GLInvAcctNbr='1004.2' THEN
						SET @lead_time_in_days = (SELECT PurLeadTime FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
						SET @moq = (SELECT MinOrderQty FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
					ELSEIF NEW.part_class='Other' THEN
						SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
						IF @check_qty_avail=0 THEN
							SET @lead_time_in_days = 0;
							SET @moq = 1;
						ELSE
							SET @lead_time_in_days = (SELECT PurLeadTime FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
							SET @moq = (SELECT MinOrderQty FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
						END IF;
					ELSE
						SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
						IF @check_qty_avail=0 THEN
							SET @lead_time_in_days = 0;
							SET @moq = 1;
						ELSE
							SET @lead_time_in_days = (SELECT PurLeadTime FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
							SET @moq = (SELECT MinOrderQty FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
						END IF;
					END IF;
				ELSE
					SET @lead_time_in_days = 0;
					SET @moq = 1;
				END IF;
			END IF;
			SET @release_group_count = @release_group_count + 1;
		END WHILE;

		SET NEW.lead_time_in_days = @lead_time_in_days;
		SET NEW.moq = @moq;
	END IF;
}
AFTER INSERT{
	-- DECLARE release_group_count INT(11);
	DECLARE max_release_group INT(11);
	DECLARE release_qtys_var VARCHAR(50);
	DECLARE rfq_items_ids_var VARCHAR(50);
	DECLARE check_item_avail VARCHAR(255);
	DECLARE sum_of_release_qty INT(11);
	DECLARE total_req_qty INT(11);

	SET @release_group_count = 1;
	SET max_release_group = (SELECT MAX(release_group) FROM 3_2rfq_items__qty WHERE rfq_id = NEW.rfq_id);

	WHILE (@release_group_count<=max_release_group) DO
		SET release_qtys_var = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
		SET rfq_items_ids_var = (SELECT group_concat(rfq_items_id ORDER BY rfq_items_id) AS rfq_items_ids FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
		IF release_qtys_var IS NOT NULL THEN
			SET sum_of_release_qty = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			-- SET @one_item_count = (SELECT group_concat(qty) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1);
			-- SET @temp_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1);
			-- SET @one_item_count = (SELECT group_concat(parent_qty_count) FROM 5_1rfq_items_bom_items_parent_count WHERE FIND_IN_SET(5_1rfq_items_bom_items_id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
			SET @one_item_count = (SELECT group_concat(T1.parent_count) FROM (SELECT SUM(parent_qty_count) AS parent_count FROM 5_1rfq_items_bom_items_parent_count WHERE FIND_IN_SET(5_1rfq_items_bom_items_id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))) GROUP BY rfq_items_bom_id) T1);
			-- SET @temp_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
			SET @temp_count = (SELECT COUNT(DISTINCT(rfq_items_bom_id)) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
			SET @count = 0;
			SET total_req_qty = 0;
			IF @temp_count>0 THEN
			DO_THIS:
			LOOP
				SET @count = @count+1;
				SET @set_one_pc_qty = SUBSTRING_INDEX(@one_item_count, ',', 1);
				SET @set_item_qty = SUBSTRING_INDEX(sum_of_release_qty, ',', 1);
				IF @set_one_pc_qty IS NULL THEN
					SET @set_one_pc_qty = 0;
				END IF;
				IF @set_item_qty IS NULL THEN
					SET @set_item_qty = 0;
				END IF;

				SET total_req_qty = total_req_qty + (@set_one_pc_qty * @set_item_qty);
				SET @one_item_count = (REPLACE(@one_item_count, CONCAT(SUBSTRING_INDEX(@one_item_count, ',', 1), ','), ''));
				SET @sum_of_release_qty = (REPLACE(@sum_of_release_qty, CONCAT(SUBSTRING_INDEX(@sum_of_release_qty, ',', 1), ','), ''));
				IF (@count >= @temp_count) THEN
					LEAVE DO_THIS;
				END IF;
			END LOOP DO_THIS;
			END IF;

			SET @get_item_id = (SELECT id FROM erp1_items WHERE ItemID=NEW.item_no AND AcctStatusFlag<>'0');
			IF @get_item_id IS NOT NULL THEN
				SET @get_GLInvAcctNbr = (SELECT GLInvAcctNbr FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
				IF @get_GLInvAcctNbr='1004.9' OR @get_GLInvAcctNbr='1004.2' THEN
					SET @source_type_auto_var = 1;
					SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
				ELSEIF NEW.part_class='Other' THEN
					SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
					IF @check_qty_avail=0 THEN
						SET @source_type_auto_var = 3;
						SET @unit_price_purchase_var = 0;
					ELSE
						SET @source_type_auto_var = 1;
						SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
					END IF;
				ELSE
					SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
					IF @check_qty_avail=0 THEN
						SET @source_type_auto_var = 2;
						SET @unit_price_purchase_var = 0;
					ELSE
						SET @source_type_auto_var = 1;
						SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=total_req_qty AND AcctStatusFlag<>'0');
					END IF;
				END IF;
			ELSE
				IF NEW.part_class='Other' THEN
					SET @source_type_auto_var = 3;
					SET @unit_price_purchase_var = 0;
				ELSE
					SET @source_type_auto_var = 2;
					SET @unit_price_purchase_var = 0;
				END IF;
			END IF;

			INSERT INTO 5_1_1_1rfq_consolidated_bom_costing SET rfq_id=NEW.rfq_id, rfq_consolidated_bom_id=NEW.id, release_group=@release_group_count, release_qtys=release_qtys_var, rfq_items_ids=rfq_items_ids_var, source_type_auto=@source_type_auto_var, required_qty=total_req_qty, unit_price_purchase=@unit_price_purchase_var;
		END IF;
		SET @release_group_count = @release_group_count + 1;
	END WHILE;

	SET @lead_time = (SELECT MAX(lead_time_in_days) FROM 5_1_1rfq_consolidated_bom WHERE rfq_id=NEW.rfq_id);
	UPDATE 3_2rfq_items__qty SET lead_time_material_in_days=@lead_time WHERE rfq_id=NEW.rfq_id;
}
AFTER UPDATE{
	DECLARE unit_price_var DECIMAL(9,6);
	DECLARE marked_price_calculate_var DECIMAL(9,6);
	DECLARE check_item_avail VARCHAR(255);
	-- DECLARE sum_of_release_qty INT(11);
	-- DECLARE total_req_qty INT(11);
	-- DECLARE max_release_group INT(11);
	IF NEW.mfg_partnumber<>OLD.mfg_partnumber THEN
		SET @release_group_count = 1;
		SET @max_release_group = (SELECT MAX(release_group) FROM 3_2rfq_items__qty WHERE rfq_id = NEW.rfq_id);
		WHILE (@release_group_count<=@max_release_group) DO
			SET @group_of_release_qty = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			SET @sum_of_release_qty = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			-- SET @one_item_count = (SELECT group_concat(parent_qty_count) FROM 5_1rfq_items_bom_items_parent_count WHERE FIND_IN_SET(5_1rfq_items_bom_items_id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
			SET @one_item_count = (SELECT group_concat(T1.parent_count) FROM (SELECT SUM(parent_qty_count) AS parent_count FROM 5_1rfq_items_bom_items_parent_count WHERE FIND_IN_SET(5_1rfq_items_bom_items_id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))) GROUP BY rfq_items_bom_id) T1);
			SET @temp_count = (SELECT COUNT(DISTINCT(rfq_items_bom_id)) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));

			SET @count = 0;
			SET @total_req_qty = 0;
			IF @temp_count>0 THEN
			DO_THIS:
			LOOP
				SET @count = @count+1;
				SET @set_one_pc_qty = SUBSTRING_INDEX(@one_item_count, ',', 1);
				SET @set_item_qty = SUBSTRING_INDEX(@sum_of_release_qty, ',', 1);
				IF @set_one_pc_qty IS NULL THEN
					SET @set_one_pc_qty = 0;
				END IF;
				IF @set_item_qty IS NULL THEN
					SET @set_item_qty = 0;
				END IF;
				SET @total_req_qty = @total_req_qty + (@set_one_pc_qty * @set_item_qty);
				SET @one_item_count = (REPLACE(@one_item_count, CONCAT(SUBSTRING_INDEX(@one_item_count, ',', 1), ','), ''));
				SET @sum_of_release_qty = (REPLACE(@sum_of_release_qty, CONCAT(SUBSTRING_INDEX(@sum_of_release_qty, ',', 1), ','), ''));
				IF (@count >= @temp_count) THEN
					LEAVE DO_THIS;
				END IF;
			END LOOP DO_THIS;
			END IF;

			SET @get_item_id = (SELECT id FROM erp1_items WHERE ItemID=NEW.item_no AND AcctStatusFlag<>'0');
			IF @get_item_id IS NOT NULL THEN
				SET @get_GLInvAcctNbr = (SELECT GLInvAcctNbr FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
				IF @get_GLInvAcctNbr='1004.9' OR @get_GLInvAcctNbr='1004.2' THEN
					SET @source_type_auto_var = 1;
					SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
				ELSEIF NEW.part_class='Other' THEN
					SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=@total_req_qty AND AcctStatusFlag<>'0');
					IF @check_qty_avail=0 THEN
						SET @source_type_auto_var = 3;
						SET @unit_price_purchase_var = 0;
					ELSE
						SET @source_type_auto_var = 1;
						SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=@total_req_qty AND AcctStatusFlag<>'0');
					END IF;
				ELSE
					SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=@total_req_qty AND AcctStatusFlag<>'0');
					IF @check_qty_avail=0 THEN
						SET @source_type_auto_var = 2;
						SET @unit_price_purchase_var = 0;
					ELSE
						SET @source_type_auto_var = 1;
						SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=@total_req_qty AND AcctStatusFlag<>'0');
					END IF;
				END IF;
			ELSE
				IF NEW.part_class='Other' THEN
					SET @source_type_auto_var = 3;
					SET @unit_price_purchase_var = 0;
				ELSE
					SET @source_type_auto_var = 2;
					SET @unit_price_purchase_var = 0;
				END IF;
			END IF;

			UPDATE 5_1_1_1rfq_consolidated_bom_costing SET source_type_auto=@source_type_auto_var, source_type_manual=NULL, octa_parts_api_response_id=NULL, unit_price_purchase=0 WHERE rfq_consolidated_bom_id=NEW.id AND release_group=@release_group_count;
			SET @release_group_count = @release_group_count + 1;
		END WHILE;		
	END IF;

	IF(OLD.markup_percentage<>NEW.markup_percentage OR OLD.markup_dollars<>NEW.markup_dollars) THEN
		SET @release_group_count = 1;
		SET @max_release_group = (SELECT MAX(release_group) FROM 3_2rfq_items__qty WHERE rfq_id = NEW.rfq_id);
		WHILE (@release_group_count<=@max_release_group) DO
			SET unit_price_var = (SELECT unit_price_purchase FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_consolidated_bom_id=NEW.id AND release_group=@release_group_count);
			-- SET marked_price_calculate_var = (unit_price_var+(unit_price_var*NEW.markup_percentage/100)+NEW.markup_dollars);
			SET marked_price_calculate_var = (unit_price_var/(1-(NEW.markup_percentage/100))+NEW.markup_dollars);

			UPDATE 5_1_1_1rfq_consolidated_bom_costing SET marked_price_calculate=marked_price_calculate_var WHERE rfq_consolidated_bom_id=NEW.id AND release_group=@release_group_count;
			SET @release_group_count = @release_group_count + 1;
		END WHILE;
	END IF;

	IF(OLD.quantity_for_one_piece<>NEW.quantity_for_one_piece) THEN
		SET @release_group_count = 1;
		SET @max_release_group = (SELECT MAX(release_group) FROM 3_2rfq_items__qty WHERE rfq_id = NEW.rfq_id);
		WHILE (@release_group_count<=@max_release_group) DO
			SET @rfq_items_ids_var = (SELECT group_concat(rfq_items_id ORDER BY rfq_items_id) AS rfq_items_ids FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			SET @group_of_release_qty = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			SET @sum_of_release_qty = (SELECT group_concat(release_qty ORDER BY rfq_items_id) FROM 3_2rfq_items__qty WHERE FIND_IN_SET (rfq_items_id, (SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET (id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1)))) AND release_group=@release_group_count);
			-- SET @total_req_qty = (@sum_of_release_qty*NEW.quantity_for_one_piece);
			-- SET @one_item_count = (SELECT group_concat(qty) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1);
			-- SET @temp_count = (SELECT COUNT(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1);
			-- SET @one_item_count = (SELECT group_concat(parent_qty_count) FROM 5_1rfq_items_bom_items_parent_count WHERE FIND_IN_SET(5_1rfq_items_bom_items_id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));
			SET @one_item_count = (SELECT group_concat(T1.parent_count) FROM (SELECT SUM(parent_qty_count) AS parent_count FROM 5_1rfq_items_bom_items_parent_count WHERE FIND_IN_SET(5_1rfq_items_bom_items_id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))) GROUP BY rfq_items_bom_id) T1);
			SET @temp_count = (SELECT COUNT(DISTINCT(rfq_items_bom_id)) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, (SELECT group_concat(id) FROM 5_1rfq_items_bom_items WHERE item_no=NEW.item_no AND rfq_id=NEW.rfq_id AND active=1 AND id NOT IN (SELECT rfq_items_bom_items_id FROM 5_1rfq_items_bom_items WHERE rfq_id=NEW.rfq_id AND rfq_items_bom_items_id<>''))));

			SET @count = 0;
			SET @total_req_qty = 0;
			IF @temp_count>0 THEN
			DO_THIS:
			LOOP
				SET @count = @count+1;
				SET @set_one_pc_qty = SUBSTRING_INDEX(@one_item_count, ',', 1);
				SET @set_item_qty = SUBSTRING_INDEX(@sum_of_release_qty, ',', 1);
				IF @set_one_pc_qty IS NULL THEN
					SET @set_one_pc_qty = 0;
				END IF;
				IF @set_item_qty IS NULL THEN
					SET @set_item_qty = 0;
				END IF;
				SET @total_req_qty = @total_req_qty + (@set_one_pc_qty * @set_item_qty);
				SET @one_item_count = (REPLACE(@one_item_count, CONCAT(SUBSTRING_INDEX(@one_item_count, ',', 1), ','), ''));
				SET @sum_of_release_qty = (REPLACE(@sum_of_release_qty, CONCAT(SUBSTRING_INDEX(@sum_of_release_qty, ',', 1), ','), ''));
				IF (@count >= @temp_count) THEN
					LEAVE DO_THIS;
				END IF;
			END LOOP DO_THIS;
			END IF;

			SET @get_item_id = (SELECT id FROM erp1_items WHERE ItemID=NEW.item_no AND AcctStatusFlag<>'0');
			IF @get_item_id IS NOT NULL THEN
				SET @get_GLInvAcctNbr = (SELECT GLInvAcctNbr FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
				IF @get_GLInvAcctNbr='1004.9' OR @get_GLInvAcctNbr='1004.2' THEN
					SET @source_type_auto_var = 1;
					SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND AcctStatusFlag<>'0');
				ELSEIF NEW.part_class='Other' THEN
					SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=@total_req_qty AND AcctStatusFlag<>'0');
					IF @check_qty_avail=0 THEN
						SET @source_type_auto_var = 3;
						SET @unit_price_purchase_var = 0;
					ELSE
						SET @source_type_auto_var = 1;
						SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=@total_req_qty AND AcctStatusFlag<>'0');
					END IF;
				ELSE
					SET @check_qty_avail = (SELECT COUNT(id) FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=@total_req_qty AND AcctStatusFlag<>'0');
					IF @check_qty_avail=0 THEN
						SET @source_type_auto_var = 2;
						SET @unit_price_purchase_var = 0;
					ELSE
						SET @source_type_auto_var = 1;
						SET @unit_price_purchase_var = (SELECT AcctValAmt FROM erp1_items WHERE id=@get_item_id AND OnHandQty>=@total_req_qty AND AcctStatusFlag<>'0');
					END IF;
				END IF;
			ELSE
				IF NEW.part_class='Other' THEN
					SET @source_type_auto_var = 3;
					SET @unit_price_purchase_var = 0;
				ELSE
					SET @source_type_auto_var = 2;
					SET @unit_price_purchase_var = 0;
				END IF;
			END IF;

			UPDATE 5_1_1_1rfq_consolidated_bom_costing SET release_qtys=@group_of_release_qty, rfq_items_ids=@rfq_items_ids_var, required_qty=@total_req_qty, source_type_auto=@source_type_auto_var WHERE rfq_consolidated_bom_id=NEW.id AND release_group=@release_group_count;
			
			SET @release_group_count = @release_group_count + 1;
		END WHILE;
	END IF;
	IF NEW.moq <> OLD.moq THEN
		-- SET value to 0, so trigger on 5_1_1_1rfq_consolidated_bom_costing can calculate correct value
		UPDATE 5_1_1_1rfq_consolidated_bom_costing SET purchase_qty = 0 WHERE rfq_consolidated_bom_id = NEW.id;
	END IF;

	IF NEW.lead_time_in_days<>OLD.lead_time_in_days THEN
		SET @lead_time = (SELECT MAX(lead_time_in_days) FROM 5_1_1rfq_consolidated_bom WHERE rfq_id=NEW.rfq_id);
		UPDATE 3_2rfq_items__qty SET lead_time_material_in_days=@lead_time WHERE rfq_id=NEW.rfq_id;
	END IF;

	-- SET @main_assembly = (SELECT group_concat(item_name) AS main_assembly FROM 3_1rfq_items WHERE FIND_IN_SET(id,(SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET(id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, NEW.rfq_items_bom_items_ids))))));
	-- UPDATE 5_1_1_1rfq_consolidated_bom_costing SET main_assembly=@main_assembly WHERE rfq_consolidated_bom_id = NEW.id;
}
AFTER DELETE{
	DELETE FROM 5_1_1_1rfq_consolidated_bom_costing WHERE rfq_consolidated_bom_id=OLD.id;

	SET @lead_time = (SELECT MAX(lead_time_in_days) FROM 5_1_1rfq_consolidated_bom WHERE rfq_id=OLD.rfq_id);
	UPDATE 3_2rfq_items__qty SET lead_time_material_in_days=@lead_time WHERE rfq_id=OLD.rfq_id;
}

DEF:5_1_1_1rfq_consolidated_bom_costing
BEFORE INSERT{
	DECLARE markup_percentage_var DECIMAL(9,6);
	DECLARE markup_dollars_var DECIMAL(9,6);
	-- DECLARE moq_var INT(11);
	-- DECLARE mul_var INT(11);
	-- DECLARE purchase_qty_count INT(11);

	IF(NEW.unit_price_purchase<>0) THEN
		SET markup_percentage_var = (SELECT markup_percentage FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
		SET markup_dollars_var = (SELECT markup_dollars FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
		-- SET NEW.marked_price_calculate = (NEW.unit_price_purchase+(NEW.unit_price_purchase*markup_percentage_var/100)+markup_dollars_var);
		SET NEW.marked_price_calculate = (NEW.unit_price_purchase/(1-(markup_percentage_var/100))+markup_dollars_var);
	END IF;
	
	SET @moq_var = (SELECT moq FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
	SET @mul_var = (SELECT multiples FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);

	SET @purchase_qty_count = 0;
	SET @required_qty_var = NEW.required_qty;
	IF(@required_qty_var<=@moq_var) THEN
		SET @purchase_qty_count = @moq_var;
	ELSE
		SET @purchase_qty_count = @moq_var;
		WHILE (@required_qty_var>@purchase_qty_count) DO
			SET @purchase_qty_count = @purchase_qty_count+@mul_var;
		END WHILE;
	END IF;

	SET NEW.purchase_qty = @purchase_qty_count;
	SET @item_id = (SELECT item_no FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
	SET @get_GLInvAcctNbr = (SELECT GLInvAcctNbr FROM erp1_items WHERE ItemID=@item_id AND AcctStatusFlag<>'0');
	SET @get_OnHandQty = (SELECT OnHandQty FROM erp1_items WHERE ItemID=@item_id AND AcctStatusFlag<>'0');
	IF @get_GLInvAcctNbr='1004.2' OR @get_GLInvAcctNbr='1004.9' THEN
		SET NEW.excess_qty = 0;
		SET NEW.purchase_qty = NEW.required_qty;
	ELSEIF @get_GLInvAcctNbr<>'' AND @get_OnHandQty>=@required_qty_var THEN
		SET NEW.excess_qty = 0;
		SET NEW.purchase_qty = NEW.required_qty;
	ELSE
		SET NEW.excess_qty = (NEW.purchase_qty-NEW.required_qty);
	END IF;

	SET NEW.price_line_total_purchase = (NEW.purchase_qty*NEW.unit_price_purchase);
	SET NEW.price_line_total_customer = (NEW.purchase_qty*NEW.marked_price_calculate);
	IF NEW.marked_price_calculate = 0 THEN
		SET NEW.marked_price_calculate = NEW.unit_price_purchase;
	END IF;

	-- SET NEW.main_assembly = (SELECT group_concat(item_name) AS main_assembly FROM 3_1rfq_items WHERE FIND_IN_SET(id,(SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET(id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, (SELECT rfq_items_bom_items_ids FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id)))))));
}
BEFORE UPDATE{
	DECLARE markup_percentage_var DECIMAL(9,6);
	DECLARE markup_dollars_var DECIMAL(9,6);
	-- DECLARE @moq_var INT(11);
	-- DECLARE mul_var INT(11);
	-- DECLARE purchase_qty_count INT(11);

	-- IF OLD.source_type_manual IS NOT NULL THEN
		-- SET NEW.source_type_auto = OLD.source_type_auto;
		-- SET NEW.unit_price_purchase = OLD.unit_price_purchase;
	-- END IF;
	
	IF(NEW.source_type_auto='manual') THEN
		IF(IFNULL(OLD.source_type_manual, 0)<>IFNULL(NEW.source_type_manual, 0) AND NEW.source_type_manual<>'manual') THEN
			SET @msg=CONCAT("You can not change source type from manual");
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;		
		END IF;
	END IF;

	IF(OLD.unit_price_purchase<>NEW.unit_price_purchase) THEN
		SET markup_percentage_var = (SELECT markup_percentage FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
		SET markup_dollars_var = (SELECT markup_dollars FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
		-- SET NEW.marked_price_calculate = (NEW.unit_price_purchase+(NEW.unit_price_purchase*markup_percentage_var/100)+markup_dollars_var);
		SET NEW.marked_price_calculate = (NEW.unit_price_purchase/(1-(markup_percentage_var/100))+markup_dollars_var);
	END IF;

	IF(OLD.required_qty<>NEW.required_qty OR OLD.purchase_qty<>NEW.purchase_qty) THEN
		SET @moq_var = (SELECT moq FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
		SET @mul_var = (SELECT multiples FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
		SET @required_qty = NEW.required_qty;
		
		IF(@required_qty<=@moq_var) THEN
			SET @purchase_qty_count = @moq_var;
		ELSE
			SET @purchase_qty_count = @moq_var;
			WHILE (@required_qty>@purchase_qty_count) DO
				SET @purchase_qty_count = @purchase_qty_count+@mul_var;
			END WHILE;
		END IF;

		SET NEW.purchase_qty = @purchase_qty_count;
		SET @item_id = (SELECT item_no FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
		SET @get_GLInvAcctNbr = (SELECT GLInvAcctNbr FROM erp1_items WHERE ItemID=@item_id AND AcctStatusFlag<>'0');
		SET @get_OnHandQty = (SELECT OnHandQty FROM erp1_items WHERE ItemID=@item_id AND AcctStatusFlag<>'0');
		IF @get_GLInvAcctNbr='1004.2' OR @get_GLInvAcctNbr='1004.9' THEN
			SET NEW.excess_qty = 0;
			SET NEW.purchase_qty = NEW.required_qty;
		ELSEIF @get_GLInvAcctNbr<>'' AND @get_OnHandQty>=@required_qty THEN
			SET NEW.excess_qty = 0;
			SET NEW.purchase_qty = NEW.required_qty;
		ELSE
			SET NEW.excess_qty = (NEW.purchase_qty-NEW.required_qty);
		END IF;
	END IF;

	IF(OLD.purchase_qty<>NEW.purchase_qty OR OLD.unit_price_purchase<>NEW.unit_price_purchase) THEN
		SET NEW.price_line_total_purchase = (NEW.purchase_qty*NEW.unit_price_purchase);
	END IF;
	IF(OLD.purchase_qty<>NEW.purchase_qty OR OLD.marked_price_calculate<>NEW.marked_price_calculate) THEN
		SET NEW.price_line_total_customer = (NEW.purchase_qty*NEW.marked_price_calculate);
	END IF;
	
	IF (NEW.source_type_manual<>'') THEN
		IF (NEW.source_type_manual = 'erp1') THEN
			SET NEW.unit_price_purchase = (SELECT AcctValAmt FROM erp1_items WHERE ItemID = (select item_no FROM 5_1_1rfq_consolidated_bom WHERE id = NEW.rfq_consolidated_bom_id) AND AcctStatusFlag<>'0');			
		END IF;
	ELSE
		IF (NEW.source_type_auto = 'erp1') THEN
			SET NEW.unit_price_purchase = (SELECT AcctValAmt FROM erp1_items WHERE ItemID = (select item_no FROM 5_1_1rfq_consolidated_bom WHERE id = NEW.rfq_consolidated_bom_id) AND AcctStatusFlag<>'0');
			IF NEW.unit_price_purchase IS NULL THEN
				SET NEW.unit_price_purchase = 0;
				SET NEW.source_type_auto = 'octaparts';
			END IF;
		END IF;
	END IF;
	
	IF NEW.marked_price_calculate = 0 THEN
		SET NEW.marked_price_calculate = NEW.unit_price_purchase;
	END IF;

	-- SET NEW.main_assembly = (SELECT group_concat(item_name) AS main_assembly FROM 3_1rfq_items WHERE FIND_IN_SET(id,(SELECT group_concat(rfq_items_id) FROM 5rfq_items_bom WHERE FIND_IN_SET(id, (SELECT group_concat(rfq_items_bom_id) FROM 5_1rfq_items_bom_items WHERE FIND_IN_SET(id, (SELECT rfq_items_bom_items_ids FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id)))))));

}
AFTER INSERT{
	CALL calculate_total_material_cost(NEW.rfq_consolidated_bom_id, NEW.rfq_id);
}
AFTER UPDATE{
	IF NEW.marked_price_calculate<>OLD.marked_price_calculate OR NEW.excess_qty<>OLD.excess_qty THEN
		CALL calculate_total_material_cost(NEW.rfq_consolidated_bom_id, NEW.rfq_id);
	END IF;
}

DEF:5_1_1_2rfq_consolidated_bom_required_vendor
BEFORE INSERT{
	DECLARE item_no VARCHAR(255);
	SET NEW.vendor_name = (SELECT vendor_name FROM m_vendors WHERE id=NEW.vendor_id);
	SET NEW.vendor_email = (SELECT vendor_email FROM m_vendors WHERE id=NEW.vendor_id);
	SET NEW.vendor_visit_read_stats = (SELECT COUNT(id) FROM 5_1_1_2rfq_consolidated_bom_required_vendor_stats WHERE rfq_consolidated_bom_required_vendor_url=NEW.vendor_url);
	SET NEW.rfq_id = (SELECT rfq_id FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
}

BEFORE UPDATE{
	IF(OLD.vendor_id<>NEW.vendor_id) THEN
		SET NEW.vendor_name = (SELECT vendor_name FROM m_vendors WHERE id=NEW.vendor_id);
		SET NEW.vendor_email = (SELECT vendor_email FROM m_vendors WHERE id=NEW.vendor_id);
	END IF;
	IF(OLD.rfq_consolidated_bom_id<>NEW.rfq_consolidated_bom_id) THEN
		SET NEW.rfq_id = (SELECT rfq_id FROM 5_1_1rfq_consolidated_bom WHERE id=NEW.rfq_consolidated_bom_id);
	END IF;
}

DEF:5_1_1_2rfq_consolidated_bom_required_vendor_price
BEFORE INSERT{
	SET NEW.vendor_id = (SELECT vendor_id FROM 5_1_1_2rfq_consolidated_bom_required_vendor WHERE id=NEW.bom_required_vendor_id);
	SET NEW.vendor_name = (SELECT vendor_name FROM m_vendors WHERE id=NEW.vendor_id);
}

DEF:5_1_1_2rfq_consolidated_bom_required_vendor_stats
AFTER INSERT{
	DECLARE visit_count INT(11);
	SET visit_count = (SELECT COUNT(id) FROM 5_1_1_2rfq_consolidated_bom_required_vendor_stats WHERE rfq_consolidated_bom_required_vendor_url=NEW.rfq_consolidated_bom_required_vendor_url);
	UPDATE 5_1_1_2rfq_consolidated_bom_required_vendor SET vendor_visit_read_stats=visit_count WHERE vendor_url=NEW.rfq_consolidated_bom_required_vendor_url;
}

DEF:6rfq_items_labor
BEFORE INSERT{
	SET NEW.rfq_id = (SELECT rfq_id FROM 3_1rfq_items WHERE id=NEW.rfq_items_id);
	SET NEW.hour = NEW.time_in_seconds/3600;
	SET NEW.total_per_piece_in_hours = NEW.activity_per_part*NEW.time_in_seconds/3600;
}

BEFORE UPDATE{
	SET NEW.hour = NEW.time_in_seconds/3600;
	SET NEW.total_per_piece_in_hours = NEW.activity_per_part*NEW.time_in_seconds/3600;
}

AFTER INSERT{
	DECLARE rfq_items_id_var INT(11);
	DECLARE rfq_id_var INT(11);
	DECLARE total_labor_hours_var DECIMAL(9,4);

	SET rfq_items_id_var = NEW.rfq_items_id;
	SET rfq_id_var = NEW.rfq_id;
	SET total_labor_hours_var = (SELECT IFNULL(SUM(total_per_piece_in_hours),0) FROM 6rfq_items_labor WHERE rfq_items_id=rfq_items_id_var);

	IF( (SELECT id from 6_1rfq_items_labor_summary WHERE rfq_items_id=rfq_items_id_var) >0) THEN
		UPDATE 6_1rfq_items_labor_summary SET rfq_items_id=rfq_items_id_var, rfq_id=rfq_id_var, total_labor_hours=total_labor_hours_var WHERE rfq_items_id=rfq_items_id_var;
	else
		INSERT INTO 6_1rfq_items_labor_summary SET rfq_items_id=rfq_items_id_var, rfq_id=rfq_id_var, total_labor_hours=total_labor_hours_var;
	END IF;
}

AFTER UPDATE{
	DECLARE labour_hrs_old DECIMAL(9,4);
	DECLARE labour_hrs DECIMAL(9,4);

	IF NEW.rfq_items_id <> OLD.rfq_items_id THEN
		SET labour_hrs_old = (SELECT IFNULL(SUM(total_per_piece_in_hours),0) FROM 6rfq_items_labor WHERE rfq_items_id=OLD.rfq_items_id AND rfq_id=OLD.rfq_id);
		UPDATE 6_1rfq_items_labor_summary SET total_labor_hours=labour_hrs_old WHERE rfq_items_id=OLD.rfq_items_id AND rfq_id=OLD.rfq_id;
	END IF;

	SET labour_hrs = (SELECT IFNULL(SUM(total_per_piece_in_hours),0) FROM 6rfq_items_labor WHERE rfq_items_id=NEW.rfq_items_id AND rfq_id=NEW.rfq_id);
	UPDATE 6_1rfq_items_labor_summary SET total_labor_hours=labour_hrs WHERE rfq_items_id=NEW.rfq_items_id AND rfq_id=NEW.rfq_id;
}

AFTER DELETE{
	SET @labour_hrs = (SELECT IFNULL(SUM(total_per_piece_in_hours),0) FROM 6rfq_items_labor WHERE rfq_items_id=OLD.rfq_items_id AND rfq_id=OLD.rfq_id);
	UPDATE 6_1rfq_items_labor_summary SET total_labor_hours=@labour_hrs WHERE rfq_items_id=OLD.rfq_items_id AND rfq_id=OLD.rfq_id;
}

DEF:6_1rfq_items_labor_summary
BEFORE INSERT{
	DECLARE gross_labor_hours_var DECIMAL(9,4);
	DECLARE margin_of_error_percentage DECIMAL(9,4);
	DECLARE setup_of_hours_percentage DECIMAL(9,4);
	
	SET gross_labor_hours_var = NEW.total_labor_hours;
	SET margin_of_error_percentage = 0;
	SET setup_of_hours_percentage = 0;
	SET margin_of_error_percentage = (gross_labor_hours_var*(NEW.margin_of_error_percentage/100));
	SET setup_of_hours_percentage = (1+(NEW.setup_of_hours_percentage/100));
	IF margin_of_error_percentage=0 AND setup_of_hours_percentage=0 THEN
		SET margin_of_error_percentage = 0;
	ELSE
		IF margin_of_error_percentage=0 THEN
			SET margin_of_error_percentage = 1;
		END IF;

		IF setup_of_hours_percentage=0 THEN
			SET setup_of_hours_percentage = 1;
		END IF;
	END IF;

	SET NEW.gross_labor_hours = gross_labor_hours_var+(margin_of_error_percentage*setup_of_hours_percentage);
	SET NEW.total_labor_cost_usa = (NEW.gross_labor_hours*NEW.labor_rate_usa);
	SET NEW.total_labor_cost_india = (NEW.gross_labor_hours*NEW.labor_rate_india);
	SET NEW.gross_labor_cost_usa = (NEW.total_labor_cost_usa/(1-(NEW.labor_margin/100)));
	SET NEW.gross_labor_cost_india = (NEW.total_labor_cost_india/(1-(NEW.labor_margin/100)));

}
BEFORE UPDATE{
	DECLARE gross_labor_hours_var DECIMAL(9,4);
	DECLARE margin_of_error_percentage DECIMAL(9,4);
	DECLARE setup_of_hours_percentage DECIMAL(9,4);

	SET gross_labor_hours_var = NEW.total_labor_hours;
	SET margin_of_error_percentage = 0;
	SET setup_of_hours_percentage = 0;
	SET margin_of_error_percentage = (gross_labor_hours_var*(NEW.margin_of_error_percentage/100));
	SET setup_of_hours_percentage = (1+(NEW.setup_of_hours_percentage/100));
	IF margin_of_error_percentage=0 AND setup_of_hours_percentage=0 THEN
		SET margin_of_error_percentage = 0;
	ELSE
		IF margin_of_error_percentage=0 THEN
			SET margin_of_error_percentage = 1;
		END IF;

		IF setup_of_hours_percentage=0 THEN
			SET setup_of_hours_percentage = 1;
		END IF;
	END IF;

	SET NEW.gross_labor_hours = gross_labor_hours_var+(margin_of_error_percentage*setup_of_hours_percentage);

	SET NEW.total_labor_cost_usa = (NEW.gross_labor_hours*NEW.labor_rate_usa);
	SET NEW.total_labor_cost_india = (NEW.gross_labor_hours*NEW.labor_rate_india);
	SET NEW.gross_labor_cost_usa = (NEW.total_labor_cost_usa/(1-(NEW.labor_margin/100)));
	SET NEW.gross_labor_cost_india = (NEW.total_labor_cost_india/(1-(NEW.labor_margin/100)));
}
AFTER INSERT{
	SET @rev_count = (SELECT COUNT(id) FROM 6_1rfq_items_labor_summary WHERE rfq_items_id=NEW.rfq_items_id AND labor_margin<>0);
	IF(@rev_count>0) THEN
		SET @labour_per = 100;
	ELSE
		SET @row_count = (SELECT COUNT(id) FROM 6_1rfq_items_labor_summary WHERE rfq_items_id=NEW.rfq_items_id);
		IF(@row_count>0) THEN
			SET @labour_per = 50;
		ELSE
			SET @labour_per = 0;
		END IF;
	END IF;

	UPDATE 3_1rfq_items SET progress_labor_percentage=@labour_per WHERE id=NEW.rfq_items_id;

	SET @total_labor_cost_usa = (SELECT SUM(gross_labor_cost_usa) FROM 6_1rfq_items_labor_summary WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id);
	SET @total_labor_cost_india = (SELECT SUM(gross_labor_cost_india) FROM 6_1rfq_items_labor_summary WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id);
	SET @total_labor_hours = (SELECT SUM(total_labor_hours) FROM 6_1rfq_items_labor_summary WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id);
	SET @total_labor_days = CEIL(@total_labor_hours/8);
	UPDATE 3_2rfq_items__qty SET total_labor_cost_usa=@total_labor_cost_usa, total_labor_cost_india=@total_labor_cost_india, lead_time_labor_production_time_in_days=@total_labor_days WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id;
}
AFTER UPDATE{
	SET @rev_count = (SELECT COUNT(id) FROM 6_1rfq_items_labor_summary WHERE rfq_items_id=NEW.rfq_items_id AND labor_margin<>0);
	IF(@rev_count>0) THEN
		SET @labour_per = 100;
	ELSE
		SET @row_count = (SELECT COUNT(id) FROM 6_1rfq_items_labor_summary WHERE rfq_items_id=NEW.rfq_items_id);
		IF(@row_count>0) THEN
			SET @labour_per = 50;
		ELSE
			SET @labour_per = 0;
		END IF;
	END IF;

	UPDATE 3_1rfq_items SET progress_labor_percentage=@labour_per WHERE id=NEW.rfq_items_id;

	IF NEW.gross_labor_cost_usa<>OLD.gross_labor_cost_usa THEN
		SET @total_labor_cost_usa = (SELECT SUM(gross_labor_cost_usa) FROM 6_1rfq_items_labor_summary WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id);
		UPDATE 3_2rfq_items__qty SET total_labor_cost_usa=@total_labor_cost_usa WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id;
	END IF;

	IF NEW.gross_labor_cost_india<>OLD.gross_labor_cost_india THEN
		SET @total_labor_cost_india = (SELECT SUM(gross_labor_cost_india) FROM 6_1rfq_items_labor_summary WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id);
		UPDATE 3_2rfq_items__qty SET total_labor_cost_india=@total_labor_cost_india WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id;
	END IF;

	IF NEW.total_labor_hours<>OLD.total_labor_hours THEN
		SET @total_labor_hours = (SELECT SUM(total_labor_hours) FROM 6_1rfq_items_labor_summary WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id);
		SET @total_labor_days = CEIL(@total_labor_hours/8);
		UPDATE 3_2rfq_items__qty SET lead_time_labor_production_time_in_days=@total_labor_days WHERE rfq_id=NEW.rfq_id AND rfq_items_id=NEW.rfq_items_id;
	END IF;
}
AFTER DELETE{
	SET @rev_count = (SELECT COUNT(id) FROM 6_1rfq_items_labor_summary WHERE rfq_items_id=OLD.rfq_items_id AND labor_margin<>0);
	IF(@rev_count>0) THEN
		SET @labour_per = 100;
	ELSE
		SET @row_count = (SELECT COUNT(id) FROM 6_1rfq_items_labor_summary WHERE rfq_items_id=OLD.rfq_items_id);
		IF(@row_count>0) THEN
			SET @labour_per = 50;
		ELSE
			SET @labour_per = 0;
		END IF;
	END IF;

	UPDATE 3_1rfq_items SET progress_labor_percentage=@labour_per WHERE id=OLD.rfq_items_id;

	SET @total_labor_cost_usa = (SELECT SUM(gross_labor_cost_usa) FROM 6_1rfq_items_labor_summary WHERE rfq_id=OLD.rfq_id AND rfq_items_id=OLD.rfq_items_id);
	SET @total_labor_cost_india = (SELECT SUM(gross_labor_cost_india) FROM 6_1rfq_items_labor_summary WHERE rfq_id=OLD.rfq_id AND rfq_items_id=OLD.rfq_items_id);
	UPDATE 3_2rfq_items__qty SET total_labor_cost_usa=@total_labor_cost_usa, total_labor_cost_india=@total_labor_cost_india WHERE rfq_id=OLD.rfq_id AND rfq_items_id=OLD.rfq_items_id;
}

DEF:7rfq_items_nre_tools
BEFORE INSERT{
	IF NEW.input_margin IS NULL THEN
		SET NEW.input_margin = 0;
	END IF;
	SET NEW.total_charge = ROUND((NEW.nre_charge/(1-(NEW.input_margin/100))), 0);
}
BEFORE UPDATE{
	IF(OLD.nre_charge<>NEW.nre_charge OR OLD.input_margin<>NEW.input_margin) THEN
		IF NEW.input_margin IS NULL THEN
			SET NEW.input_margin = 0;
		END IF;
		SET NEW.total_charge = ROUND((NEW.nre_charge/(1-(NEW.input_margin/100))), 0);
	END IF;
}
AFTER INSERT{
	SET @total_charge = (SELECT SUM(total_charge) FROM 7rfq_items_nre_tools WHERE rfq_items_id=NEW.rfq_items_id);
	UPDATE 3_2rfq_items__qty SET total_nre_tools_value=@total_charge WHERE rfq_items_id=NEW.rfq_items_id;
}
AFTER UPDATE{
	IF OLD.total_charge<>NEW.total_charge THEN
		SET @total_charge = (SELECT SUM(total_charge) FROM 7rfq_items_nre_tools WHERE rfq_items_id=NEW.rfq_items_id);
		UPDATE 3_2rfq_items__qty SET total_nre_tools_value=@total_charge WHERE rfq_items_id=NEW.rfq_items_id;
	END IF;
}
AFTER DELETE{
	SET @total_charge = (SELECT SUM(total_charge) FROM 7rfq_items_nre_tools WHERE rfq_items_id=OLD.rfq_items_id);
	UPDATE 3_2rfq_items__qty SET total_nre_tools_value=@total_charge WHERE rfq_items_id=OLD.rfq_items_id;	
}

DEF:8rfq_items_assumptions
AFTER INSERT{
	SET @assumption_count = (SELECT COUNT(id) FROM 8rfq_items_assumptions WHERE rfq_items_id=NEW.rfq_items_id);
	UPDATE 3_1rfq_items SET no_of_assumptions=@assumption_count WHERE id=NEW.rfq_items_id;
}
AFTER DELETE{
	SET @assumption_count = (SELECT COUNT(id) FROM 8rfq_items_assumptions WHERE rfq_items_id=OLD.rfq_items_id);
	UPDATE 3_1rfq_items SET no_of_assumptions=@assumption_count WHERE id=OLD.rfq_items_id;
}
BEFORE INSERT{
	SET NEW.rfq_id = (SELECT rfq_id FROM 3_1rfq_items WHERE id=NEW.rfq_items_id);
	SET NEW.assumption_entered_by_user = @app_username;
}

DEF:9rfq_outboundfreight
BEFORE INSERT{
	SET NEW.rfq_id = (SELECT rfq_id FROM 3_1rfq_items WHERE id=NEW.rfq_items_id);
}

DEF:10messages
BEFORE INSERT{
	SET NEW.no_of_responses_to_this_msg = 0;
	SET NEW.rfq_id = (SELECT rfq_id FROM 3_1rfq_items WHERE id=NEW.rfq_items_id);
	SET NEW.customer_id = (SELECT customer_id FROM 2rfq_request WHERE id=NEW.rfq_id);
}
AFTER INSERT{

	SET @no_of_unreads_customer = (SELECT COUNT(id) FROM 10messages WHERE customer_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM 10messages WHERE engineer_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_manager = (SELECT COUNT(id) FROM 10messages WHERE manager_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_csr = (SELECT COUNT(id) FROM 10messages WHERE csr_read=0 AND rfq_items_id=NEW.rfq_items_id);

	SET @no_of_alerts_count = (SELECT COUNT(id) FROM 10messages WHERE rfq_items_id=NEW.rfq_items_id AND `type`=3);
	UPDATE 3_1rfq_items SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=NEW.rfq_items_id;
}
AFTER UPDATE{
	SET @no_of_unreads_customer = (SELECT COUNT(id) FROM 10messages WHERE customer_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM 10messages WHERE engineer_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_manager = (SELECT COUNT(id) FROM 10messages WHERE manager_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_csr = (SELECT COUNT(id) FROM 10messages WHERE csr_read=0 AND rfq_items_id=NEW.rfq_items_id);

	SET @no_of_alerts_count = (SELECT COUNT(id) FROM 10messages WHERE rfq_items_id=NEW.rfq_items_id AND `type`=3);
	UPDATE 3_1rfq_items SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=NEW.rfq_items_id;
}
AFTER DELETE{
	IF OLD.reply_to IS NULL THEN

		SET @no_of_unreads_customer = (SELECT COUNT(id) FROM 10messages WHERE customer_read=0 AND rfq_items_id=OLD.rfq_items_id);
		SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM 10messages WHERE engineer_read=0 AND rfq_items_id=OLD.rfq_items_id);
		SET @no_of_unreads_manager = (SELECT COUNT(id) FROM 10messages WHERE manager_read=0 AND rfq_items_id=OLD.rfq_items_id);
		SET @no_of_unreads_csr = (SELECT COUNT(id) FROM 10messages WHERE csr_read=0 AND rfq_items_id=OLD.rfq_items_id);

		SET @no_of_alerts_count = (SELECT COUNT(id) FROM 10messages WHERE rfq_items_id=OLD.rfq_items_id AND `type`=3);
		UPDATE 3_1rfq_items SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=OLD.rfq_items_id;
	ELSE
		SET @msg=CONCAT("You can not delete message");
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;
}

DEF:10_1_1messages_attachment_stats
AFTER INSERT{
	SET @customer_read_count = (SELECT COUNT(id) FROM 10_1_1messages_attachment_stats WHERE messages_attachment_id=NEW.messages_attachment_id);
	UPDATE 10_1messages_attachment SET customer_read_count=@customer_read_count WHERE id=NEW.messages_attachment_id;
}
AFTER DELETE{
	SET @customer_read_count = (SELECT COUNT(id) FROM 10_1_1messages_attachment_stats WHERE messages_attachment_id=OLD.messages_attachment_id);
	UPDATE 10_1messages_attachment SET customer_read_count=@customer_read_count WHERE id=OLD.messages_attachment_id;
}

DEF:octaparts_response_price
BEFORE INSERT{ 
  SET @octaparts_request_data_id = (SELECT octaparts_request_data_id FROM octaparts_response_offers WHERE id=NEW.octaparts_response_offers_id);
  SET NEW.mfg_partnumber = (SELECT mfg_part_number FROM octaparts_request_data WHERE id=@octaparts_request_data_id);
  SET NEW.octaparts_request_data_id = @octaparts_request_data_id;
}

DEF:inbox
BEFORE INSERT{
	SET NEW.rfq_request_id = (SELECT id FROM 2rfq_request WHERE id_encrypt=NEW.rfq_request_id_encrypt);
	SET NEW.rfq_id = (SELECT id FROM 3rfq WHERE rfq_request_id=NEW.rfq_request_id);
	SET NEW.no_of_responses_to_this_msg = 0;
	SET NEW.customer_id = (SELECT customer_id FROM 2rfq_request WHERE id=NEW.rfq_request_id);
}
AFTER INSERT{
	SET @no_of_unreads_customer = (SELECT COUNT(id) FROM inbox WHERE customer_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM inbox WHERE engineer_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_manager = (SELECT COUNT(id) FROM inbox WHERE manager_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_csr = (SELECT COUNT(id) FROM inbox WHERE csr_read=0 AND rfq_items_id=NEW.rfq_items_id);

	SET @no_of_alerts_count = (SELECT COUNT(id) FROM inbox WHERE rfq_items_id=NEW.rfq_items_id AND `type`=3);
	UPDATE 3_1rfq_items SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=NEW.rfq_items_id;

	SET @no_of_unreads_customer = (SELECT COUNT(id) FROM inbox WHERE customer_read=0 AND rfq_request_id=NEW.rfq_request_id);
	SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM inbox WHERE engineer_read=0 AND rfq_request_id=NEW.rfq_request_id);
	SET @no_of_unreads_manager = (SELECT COUNT(id) FROM inbox WHERE manager_read=0 AND rfq_request_id=NEW.rfq_request_id);
	SET @no_of_unreads_csr = (SELECT COUNT(id) FROM inbox WHERE csr_read=0 AND rfq_request_id=NEW.rfq_request_id);

	SET @no_of_alerts_count = (SELECT COUNT(id) FROM inbox WHERE rfq_request_id=NEW.rfq_request_id AND `type`=3);
	UPDATE 3rfq SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=NEW.rfq_id;
}
AFTER UPDATE{
	SET @no_of_unreads_customer = (SELECT COUNT(id) FROM inbox WHERE customer_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM inbox WHERE engineer_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_manager = (SELECT COUNT(id) FROM inbox WHERE manager_read=0 AND rfq_items_id=NEW.rfq_items_id);
	SET @no_of_unreads_csr = (SELECT COUNT(id) FROM inbox WHERE csr_read=0 AND rfq_items_id=NEW.rfq_items_id);

	SET @no_of_alerts_count = (SELECT COUNT(id) FROM inbox WHERE rfq_items_id=NEW.rfq_items_id AND `type`=3);
	UPDATE 3_1rfq_items SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=NEW.rfq_items_id;

	SET @no_of_unreads_customer = (SELECT COUNT(id) FROM inbox WHERE customer_read=0 AND rfq_request_id=NEW.rfq_request_id);
	SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM inbox WHERE engineer_read=0 AND rfq_request_id=NEW.rfq_request_id);
	SET @no_of_unreads_manager = (SELECT COUNT(id) FROM inbox WHERE manager_read=0 AND rfq_request_id=NEW.rfq_request_id);
	SET @no_of_unreads_csr = (SELECT COUNT(id) FROM inbox WHERE csr_read=0 AND rfq_request_id=NEW.rfq_request_id);

	SET @no_of_alerts_count = (SELECT COUNT(id) FROM inbox WHERE rfq_request_id=NEW.rfq_request_id AND `type`=3);
	UPDATE 3rfq SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=NEW.rfq_id;
}
AFTER DELETE{
	IF OLD.reply_to IS NULL THEN
		SET @no_of_unreads_customer = (SELECT COUNT(id) FROM inbox WHERE customer_read=0 AND rfq_items_id=OLD.rfq_items_id);
		SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM inbox WHERE engineer_read=0 AND rfq_items_id=OLD.rfq_items_id);
		SET @no_of_unreads_manager = (SELECT COUNT(id) FROM inbox WHERE manager_read=0 AND rfq_items_id=OLD.rfq_items_id);
		SET @no_of_unreads_csr = (SELECT COUNT(id) FROM inbox WHERE csr_read=0 AND rfq_items_id=OLD.rfq_items_id);

		SET @no_of_alerts_count = (SELECT COUNT(id) FROM inbox WHERE rfq_items_id=OLD.rfq_items_id AND `type`=3);
		UPDATE 3_1rfq_items SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=OLD.rfq_items_id;

		SET @no_of_unreads_customer = (SELECT COUNT(id) FROM inbox WHERE customer_read=0 AND rfq_request_id=OLD.rfq_request_id);
		SET @no_of_unreads_engineer = (SELECT COUNT(id) FROM inbox WHERE engineer_read=0 AND rfq_request_id=OLD.rfq_request_id);
		SET @no_of_unreads_manager = (SELECT COUNT(id) FROM inbox WHERE manager_read=0 AND rfq_request_id=OLD.rfq_request_id);
		SET @no_of_unreads_csr = (SELECT COUNT(id) FROM inbox WHERE csr_read=0 AND rfq_request_id=OLD.rfq_request_id);

		SET @no_of_alerts_count = (SELECT COUNT(id) FROM inbox WHERE rfq_request_id=OLD.rfq_request_id AND `type`=3);
		UPDATE 3rfq SET no_of_alerts=@no_of_alerts_count, no_of_unreads_customer=@no_of_unreads_customer, no_of_unreads_engineer=@no_of_unreads_engineer, no_of_unreads_manager=@no_of_unreads_manager, no_of_unreads_csr=@no_of_unreads_csr WHERE id=OLD.rfq_id;
	ELSE
		SET @msg=CONCAT("You can not delete message");
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg;
	END IF;
}

DEF:inbox_attachments
BEFORE INSERT{
	SET NEW.rfq_request_id = (SELECT rfq_request_id FROM inbox WHERE id=NEW.inbox_id);
}
AFTER INSERT{
	IF NEW.rfq_request_id IS NOT NULL THEN
		INSERT INTO 2_1rfq_request_attachments SET rfq_request_id=NEW.rfq_request_id, upload_file_path=NEW.attached_path;
	END IF;	
}

DEF:inbox_attachments_stats
AFTER INSERT{
	SET @customer_read_count = (SELECT COUNT(id) FROM inbox_attachments_stats WHERE inbox_attachments_id=NEW.inbox_attachments_id);
	UPDATE inbox_attachments SET customer_read_count=@customer_read_count WHERE id=NEW.inbox_attachments_id;
}
AFTER DELETE{
	SET @customer_read_count = (SELECT COUNT(id) FROM inbox_attachments_stats WHERE inbox_attachments_id=OLD.inbox_attachments_id);
	UPDATE inbox_attachments SET customer_read_count=@customer_read_count WHERE id=OLD.inbox_attachments_id;
}

DEF:m_users
AFTER INSERT{
	IF NEW.user_type='admin' THEN
		INSERT INTO m_user_roles_assigned SET user_id=NEW.id, role_id=1;
	END IF;
	IF NEW.user_type='engineermanager' THEN
		INSERT INTO m_user_roles_assigned SET user_id=NEW.id, role_id=2;
	END IF;
	IF NEW.user_type='engineer' THEN
		INSERT INTO m_user_roles_assigned SET user_id=NEW.id, role_id=3;
	END IF;
	IF NEW.user_type='csr' THEN
		INSERT INTO m_user_roles_assigned SET user_id=NEW.id, role_id=4;
	END IF;
	IF NEW.user_type='customer' THEN
		INSERT INTO m_user_roles_assigned SET user_id=NEW.id, role_id=5;
	END IF;
}
AFTER UPDATE{
	IF NEW.user_type<>OLD.user_type THEN
		IF NEW.user_type='admin' THEN
			UPDATE m_user_roles_assigned SET role_id=1 WHERE user_id=NEW.id;
		END IF;
		IF NEW.user_type='engineermanager' THEN
			UPDATE m_user_roles_assigned SET role_id=2 WHERE user_id=NEW.id;
		END IF;
		IF NEW.user_type='engineer' THEN
			UPDATE m_user_roles_assigned SET role_id=3 WHERE user_id=NEW.id;
		END IF;
		IF NEW.user_type='csr' THEN
			UPDATE m_user_roles_assigned SET role_id=4 WHERE user_id=NEW.id;
		END IF;
		IF NEW.user_type='customer' THEN
			UPDATE m_user_roles_assigned SET role_id=5 WHERE user_id=NEW.id;
		END IF;
	END IF;
}

DEF:rfq_freez_data
BEFORE INSERT{
	IF NEW.rfq_items_id IS NOT NULL THEN
		SET NEW.item_id = (SELECT item_id FROM 3_1rfq_items WHERE id=NEW.rfq_items_id);
	END IF;
}