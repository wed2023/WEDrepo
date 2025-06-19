DECLARE
  l_request_id NUMBER := :P10_REQUEST_ID;
  l_purchase_request PurchaseRequests%ROWTYPE;
  l_requested_by_name Users.UserName%TYPE;
  l_supplier_name Suppliers.SupplierName%TYPE;
  l_item_product_name Products.ProductName%TYPE;
  l_item_currency_name Currencies.CurrencyName%TYPE;
  l_main_currency_code VARCHAR2(10) := 'USD'; -- Defaulting to USD for now as the fetching logic is commented out
  l_items_found BOOLEAN := FALSE;

  CURSOR c_request_items (p_request_id IN NUMBER) IS
    SELECT pri.*
    FROM PurchaseRequestItems pri
    WHERE pri.RequestID = p_request_id;

BEGIN
  -- Validate P10_REQUEST_ID
  IF l_request_id IS NULL THEN
    htp.p('<div class="u-alert u-alert--danger" role="alert"><p>Error: Request ID is missing (P10_REQUEST_ID).</p></div>');
    RETURN NULL;
  END IF;

  -- Fetch main purchase request details
  BEGIN
    SELECT pr.RequestID,
           pr.RequestDate,
           pr.RequestedBy,
           pr.SupplierID,
           pr.Status
    INTO   l_purchase_request.RequestID,
           l_purchase_request.RequestDate,
           l_purchase_request.RequestedBy,
           l_purchase_request.SupplierID,
           l_purchase_request.Status
    FROM   PurchaseRequests pr
    WHERE  pr.RequestID = l_request_id;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      htp.p('<div class="u-alert u-alert--warning" role="alert"><p>Purchase request not found for ID: ' || apex_escape.html(TO_CHAR(l_request_id)) || '</p></div>');
      RETURN NULL;
    WHEN OTHERS THEN
      htp.p('<div class="u-alert u-alert--danger" role="alert"><p>Error fetching purchase request: ' || apex_escape.html(SQLERRM) || '</p></div>');
      RETURN NULL;
  END;

  /* -- Start of commented out block for currency fetching
  -- Fetch CurrencyCode from the first item of the PurchaseRequest for display purposes (e.g., grand total)
  DECLARE
    l_first_item_currency_id PurchaseRequestItems.CurrencyID%TYPE;
  BEGIN
    SELECT pri.CurrencyID
    INTO l_first_item_currency_id
    FROM PurchaseRequestItems pri
    WHERE pri.RequestID = l_request_id
    AND ROWNUM = 1; -- Get CurrencyID from the first item

    IF l_first_item_currency_id IS NOT NULL THEN
      BEGIN
        SELECT c.CurrencyCode
        INTO l_main_currency_code
        FROM Currencies c
        WHERE c.CurrencyID = l_first_item_currency_id;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_main_currency_code := 'N/A'; -- Currency code not found for the item's currency ID
        WHEN OTHERS THEN
          l_main_currency_code := 'ERR'; -- Error fetching currency code
      END;
    ELSE
      l_main_currency_code := ''; -- No currency ID on the first item
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_main_currency_code := ''; -- No items found for the request, so no currency code
    WHEN OTHERS THEN
      l_main_currency_code := 'ERR'; -- Error fetching first item's currency
  END;
  -- End of commented out block for currency fetching */

  -- Fetch related names (Requested By, Supplier)
  BEGIN
    SELECT u.UserName INTO l_requested_by_name FROM Users u WHERE u.UserID = l_purchase_request.RequestedBy;
  EXCEPTION WHEN OTHERS THEN l_requested_by_name := apex_escape.html(TO_CHAR(l_purchase_request.RequestedBy)); END;

  BEGIN
    SELECT s.SupplierName INTO l_supplier_name FROM Suppliers s WHERE s.SupplierID = l_purchase_request.SupplierID;
  EXCEPTION WHEN OTHERS THEN l_supplier_name := apex_escape.html(TO_CHAR(l_purchase_request.SupplierID)); END;

  -- Display Purchase Request Header
  htp.p('<h3>Purchase Request Details</h3>');
  htp.p('<hr>');
  htp.p('<div class="container">');
  htp.p('<div class="row">');
  htp.p('<div class="col col-6">');
  htp.p('<ul class="fa-ul">');
  htp.p('<li><span class="fa-li"><i class="fa fa-id-card"></i></span><b>Request ID:</b> ' || apex_escape.html(TO_CHAR(l_purchase_request.RequestID)) || '</li>');
  htp.p('<li><span class="fa-li"><i class="fa fa-calendar"></i></span><b>Request Date:</b> ' || apex_escape.html(TO_CHAR(l_purchase_request.RequestDate, 'DD-MON-YYYY HH24:MI')) || '</li>');
  htp.p('</ul></div>');
  htp.p('<div class="col col-6">');
  htp.p('<ul class="fa-ul">');
  htp.p('<li><span class="fa-li"><i class="fa fa-user"></i></span><b>Requested By:</b> ' || l_requested_by_name || '</li>');
  htp.p('<li><span class="fa-li"><i class="fa fa-truck"></i></span><b>Supplier:</b> ' || l_supplier_name || '</li>');
  htp.p('</ul></div></div>');

  htp.p('<div class="row"><div class="col col-12">');
  htp.p('<label for="p_request_status_dyn"><b>Status:</b></label>');
  htp.p('<select name="p_request_status" id="p_request_status_dyn" class="selectlist apex-item-select">');
  htp.p('<option value="Pending"' || CASE WHEN l_purchase_request.Status = 'Pending' THEN ' selected="selected"' ELSE '' END || '>Pending</option>');
  htp.p('<option value="Approved"' || CASE WHEN l_purchase_request.Status = 'Approved' THEN ' selected="selected"' ELSE '' END || '>Approved</option>');
  htp.p('<option value="Rejected"' || CASE WHEN l_purchase_request.Status = 'Rejected' THEN ' selected="selected"' ELSE '' END || '>Rejected</option>');
  htp.p('</select>');
  htp.p('</div></div></div>');

  htp.p('<br>');
  htp.p('<h3>Request Items</h3>');
  htp.p('<hr>');

  htp.p('<div class="table-container">');
  htp.p('<table class="a-IRR-table" summary="Purchase Request Items">');
  htp.p('<thead><tr>');
  htp.p('<th id="th_product">Product</th>');
  htp.p('<th id="th_quantity" class="u-textRight">Quantity</th>');
  htp.p('<th id="th_unit_price" class="u-textRight">Unit Price</th>');
  htp.p('<th id="th_subtotal" class="u-textRight">Subtotal</th>');
  htp.p('<th id="th_currency">Currency</th>');
  htp.p('<th id="th_unit">Unit</th>');
  htp.p('<th id="th_note">Note</th>');
  htp.p('<th id="th_expiry_date">Expiry Date</th>');
  htp.p('</tr></thead>');
  htp.p('<tbody>');

  FOR item_rec IN c_request_items(l_request_id) LOOP
    l_items_found := TRUE;

    BEGIN
      SELECT p.ProductName INTO l_item_product_name FROM Products p WHERE p.ProductID = item_rec.ProductID;
    EXCEPTION WHEN OTHERS THEN l_item_product_name := apex_escape.html(TO_CHAR(item_rec.ProductID)); END;

    BEGIN
      SELECT c.CurrencyName INTO l_item_currency_name FROM Currencies c WHERE c.CurrencyID = item_rec.CurrencyID;
    EXCEPTION WHEN OTHERS THEN l_item_currency_name := apex_escape.html(TO_CHAR(item_rec.CurrencyID)); END;

    htp.p('<tr>');
    htp.prn(apex_item.hidden(p_idx => 1, p_value => item_rec.RequestItemID, p_item_id => 'f01_' || item_rec.RequestItemID));

    htp.p('<td headers="th_product">' || apex_escape.html(l_item_product_name) || '</td>');

    htp.p('<td headers="th_quantity" class="u-textRight">');
    htp.prn(apex_item.text(
              p_idx        => 2,
              p_value      => item_rec.Quantity,
              p_attributes => 'class="number_field apex-item-text u-textRight" size="10" maxlength="10" data-itemid="'|| item_rec.RequestItemID ||'"',
              p_item_id    => 'f02_' || item_rec.RequestItemID,
              p_item_label => apex_escape.html('Quantity for ' || item_rec.RequestItemID)
            ));
    htp.p('</td>');

    htp.p('<td headers="th_unit_price" class="u-textRight">');
    htp.prn(apex_item.text(
              p_idx        => 3,
              p_value      => item_rec.UnitPrice,
              p_attributes => 'class="number_field apex-item-text u-textRight" size="10" maxlength="10" step="any" data-itemid="'|| item_rec.RequestItemID ||'"',
              p_item_id    => 'f03_' || item_rec.RequestItemID,
              p_item_label => apex_escape.html('Unit Price for ' || item_rec.RequestItemID)
            ));
    htp.p('</td>');

    htp.p('<td headers="th_subtotal" class="u-textRight"><span id="item_subtotal_' || item_rec.RequestItemID || '" class="item-subtotal">0.00</span></td>');

    htp.p('<td headers="th_currency">' || apex_escape.html(l_item_currency_name) || '</td>');
    htp.p('<td headers="th_unit">' || apex_escape.html(item_rec.Unit) || '</td>');
    htp.p('<td headers="th_note">' || apex_escape.html(item_rec.Note) || '</td>');

    htp.p('<td headers="th_expiry_date">');
    htp.prn(apex_item.date_popup(
              p_idx         => 4,
              p_value       => item_rec.ExpiryDate,
              p_date_format => 'YYYY-MM-DD',
              p_attributes  => 'size="12" maxlength="10" class="apex-item-date"',
              p_item_id     => 'f04_' || item_rec.RequestItemID,
              p_item_label  => apex_escape.html('Expiry Date for ' || item_rec.RequestItemID)
            ));
    htp.p('</td>');
    htp.p('</tr>');
  END LOOP;

  IF NOT l_items_found THEN
    htp.p('<tr><td colspan="8" class="u-alignCenter">No items found for this request.</td></tr>');
  END IF;

  htp.p('</tbody></table></div>');

  htp.p('<div style="text-align: right; margin-top: 10px; padding-right: 20px;">');
  htp.p('<strong>Total Amount: </strong><span id="grand_total_display" data-currency-code="'||apex_escape.html_attribute(l_main_currency_code)||'">0.00</span>');
  htp.p('</div>');

  htp.p('<br>');
  htp.p('<h3>Additional Information</h3>');
  htp.p('<hr>');
  htp.p('<div class="container">');
  htp.p('<div class="row">');
  htp.p('<div class="col col-6">');
  htp.p('<label for="p_cashbox_id_dyn">CashBox ID:</label>');
  htp.p('<input type="text" name="p_cashbox_id" id="p_cashbox_id_dyn" class="text_field apex-item-text">');
  htp.p('</div>');
  htp.p('<div class="col col-6">');
  htp.p('<label for="p_warehouse_id_dyn">Warehouse ID:</label>');
  htp.p('<input type="text" name="p_warehouse_id" id="p_warehouse_id_dyn" class="text_field apex-item-text">');
  htp.p('</div></div></div>');

  RETURN NULL;

EXCEPTION
  WHEN OTHERS THEN
    htp.p('<div class="u-alert u-alert--danger" role="alert"><p>An unexpected error occurred in the dynamic content region: ' || apex_escape.html(SQLERRM) || '</p><pre>' || dbms_utility.format_error_stack || '</pre><pre>' || dbms_utility.format_error_backtrace || '</pre></div>');
    RETURN NULL;
END;
/
