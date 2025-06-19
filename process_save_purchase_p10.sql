DECLARE
  l_request_id        PurchaseRequests.RequestID%TYPE := :P10_REQUEST_ID;
  l_request_status    PurchaseRequests.Status%TYPE := :P10_REQUEST_STATUS; -- APEX page item for the new status of the PurchaseRequest
  l_cashbox_id        Purchases.CashBoxID%TYPE := :P10_CASHBOX_ID;     -- APEX page item
  l_warehouse_id      Purchases.WarehouseID%TYPE := :P10_WAREHOUSE_ID;   -- APEX page item

  l_supplier_id       PurchaseRequests.SupplierID%TYPE;
  l_pr_currency_id    PurchaseRequests.CurrencyID%TYPE; -- Assuming CurrencyID exists in PurchaseRequests and represents the main currency for the request.

  l_purchase_id       Purchases.PurchaseID%TYPE;
  l_product_id        PurchaseRequestItems.ProductID%TYPE;
  l_unit              PurchaseRequestItems.Unit%TYPE;
  l_total_amount      Purchases.TotalAmount%TYPE := 0;

  l_err_msg           VARCHAR2(4000);
  l_validation_failed BOOLEAN := FALSE;

BEGIN
  -- 1. Values are assigned from APEX page items in the declaration section.
  --    apex_application.g_fxx arrays will be accessed directly in the loop.
  --    CRITICAL ASSUMPTION: The dynamic content region (previous step) MUST be modified
  --    to submit RequestItemID as apex_application.g_f01 for each item row.
  --    Example: htp.p(apex_item.hidden(p_idx => 1, p_value => item_rec.RequestItemID));
  --    Quantities should be g_f02, UnitPrices g_f03, ExpiryDates g_f04.

  -- 2. Basic Validation
  IF l_request_id IS NULL THEN
    l_validation_failed := TRUE;
    apex_error.add_error (
      p_message          => 'Request ID is missing. Cannot process purchase.',
      p_display_location => apex_error.c_inline_in_notification );
  END IF;

  IF l_request_status IS NULL THEN
    l_validation_failed := TRUE;
    apex_error.add_error (
      p_message          => 'New Purchase Request status is missing.',
      p_display_location => apex_error.c_inline_in_notification );
  END IF;

  -- Validate CashBoxID and WarehouseID if they are mandatory
  IF l_cashbox_id IS NULL THEN -- Assuming CashBoxID is mandatory
    l_validation_failed := TRUE;
    apex_error.add_error (
      p_message          => 'CashBox ID is required.',
      p_display_location => apex_error.c_inline_in_notification );
  END IF;

  IF l_warehouse_id IS NULL THEN -- Assuming WarehouseID is mandatory
    l_validation_failed := TRUE;
    apex_error.add_error (
      p_message          => 'Warehouse ID is required.',
      p_display_location => apex_error.c_inline_in_notification );
  END IF;


  IF l_validation_failed THEN
    RETURN; -- Stop processing if validation failed
  END IF;

  -- 3. Transaction management: APEX handles this implicitly for page processes,
  --    but explicit COMMIT/ROLLBACK is used for clarity and control.

  -- 4. Insert a record into Purchases
  --    Fetch SupplierID and CurrencyID from the original PurchaseRequest.
  BEGIN
    SELECT pr.SupplierID, pr.CurrencyID -- CRITICAL: Assumes CurrencyID exists on PurchaseRequests table.
    INTO l_supplier_id, l_pr_currency_id
    FROM PurchaseRequests pr
    WHERE pr.RequestID = l_request_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      apex_error.add_error (
        p_message          => 'Original Purchase Request (ID: ' || l_request_id || ') not found. Cannot create purchase.',
        p_display_location => apex_error.c_inline_in_notification );
      RAISE; -- Re-raise to be caught by the main exception handler and trigger rollback
    WHEN OTHERS THEN
      apex_error.add_error (
        p_message          => 'Error fetching Supplier/Currency from Purchase Request: ' || SQLERRM,
        p_display_location => apex_error.c_inline_in_notification );
      RAISE;
  END;

  -- Ensure CurrencyID is available for the Purchases table
  -- This assumes Purchases table also has a CurrencyID column.
  IF l_pr_currency_id IS NULL THEN
      apex_error.add_error (
        p_message          => 'CurrencyID is missing on the original Purchase Request. Cannot create purchase.',
        p_display_location => apex_error.c_inline_in_notification );
      RAISE_APPLICATION_ERROR(-20004, 'CurrencyID missing on PurchaseRequest');
  END IF;

  INSERT INTO Purchases (
    RequestID,
    SupplierID,
    CurrencyID,     -- This field must exist in the Purchases table
    PurchaseDate,
    CashBoxID,
    WarehouseID,
    StatusPurchases,
    TotalAmount     -- Will be updated later
    -- PeriodID     -- Assuming a trigger handles this based on PurchaseDate
  ) VALUES (
    l_request_id,
    l_supplier_id,
    l_pr_currency_id, -- Using the CurrencyID from the PurchaseRequest
    SYSDATE,
    l_cashbox_id,
    l_warehouse_id,
    'DRAFT',        -- Initial status for the new purchase
    0               -- Initial total amount, will be updated
  ) RETURNING PurchaseID INTO l_purchase_id;

  -- 5. Loop through items and insert into PurchaseDetails
  IF apex_application.g_f01 IS NOT NULL AND apex_application.g_f01.COUNT > 0 THEN
    FOR i IN 1..apex_application.g_f01.COUNT LOOP
      DECLARE
        l_request_item_id PurchaseRequestItems.RequestItemID%TYPE;
        l_quantity        PurchaseDetails.Quantity%TYPE;
        l_price           PurchaseDetails.Price%TYPE;
        l_expiry_date_str VARCHAR2(100); -- Raw value from APEX array
        l_expiry_date     PurchaseDetails.ExpiryDate%TYPE;
      BEGIN
        l_request_item_id := TO_NUMBER(apex_application.g_f01(i)); -- RequestItemID from hidden field (g_f01)
        l_quantity        := TO_NUMBER(apex_application.g_f02(i)); -- Quantity from text field (g_f02)
        l_price           := TO_NUMBER(apex_application.g_f03(i)); -- Unit Price from text field (g_f03)
        l_expiry_date_str := apex_application.g_f04(i);            -- Expiry Date from date picker (g_f04)

        -- Per-item validation
        IF l_quantity IS NULL OR l_quantity < 0 THEN
            apex_error.add_error(p_message => 'Invalid quantity for item (RequestItemID: ' || l_request_item_id || '). Must be a non-negative number.', p_display_location => apex_error.c_inline_in_notification);
            RAISE_APPLICATION_ERROR(-20001, 'Invalid quantity for item ' || l_request_item_id);
        END IF;
        IF l_price IS NULL OR l_price < 0 THEN
            apex_error.add_error(p_message => 'Invalid price for item (RequestItemID: ' || l_request_item_id || '). Must be a non-negative number.', p_display_location => apex_error.c_inline_in_notification);
            RAISE_APPLICATION_ERROR(-20002, 'Invalid price for item ' || l_request_item_id);
        END IF;

        -- Process ExpiryDate
        IF l_expiry_date_str IS NOT NULL THEN
          BEGIN
            -- Adjust date format 'YYYY-MM-DD' if your APEX date picker uses a different one.
            -- Common APEX date picker format is 'YYYY-MM-DDTHH24:MI:SS' or 'DD-MON-YYYY'.
            -- For safety, explicitly use a known format or use TRUNC if time part is irrelevant.
            l_expiry_date := TO_DATE(SUBSTR(l_expiry_date_str, 1, 10), 'YYYY-MM-DD');
          EXCEPTION
            WHEN OTHERS THEN
              apex_error.add_error(
                p_message => 'Invalid Expiry Date format for item (RequestItemID: ' || l_request_item_id || '). Expected YYYY-MM-DD. Value: ' || l_expiry_date_str,
                p_display_location => apex_error.c_inline_in_notification
              );
              RAISE_APPLICATION_ERROR(-20003, 'Invalid Expiry Date format for item ' || l_request_item_id);
          END;
        ELSE
          l_expiry_date := NULL;
        END IF;

        -- Fetch ProductID and Unit from the original PurchaseRequestItems
        BEGIN
          SELECT pri.ProductID, pri.Unit
          INTO l_product_id, l_unit
          FROM PurchaseRequestItems pri
          WHERE pri.RequestItemID = l_request_item_id;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            apex_error.add_error (
              p_message          => 'Original Purchase Request Item details not found for RequestItemID: ' || l_request_item_id,
              p_display_location => apex_error.c_inline_in_notification );
            RAISE; -- Re-raise to be caught by the main exception handler
          WHEN OTHERS THEN
            apex_error.add_error (
              p_message          => 'Error fetching Product/Unit for RequestItemID '|| l_request_item_id || ': ' || SQLERRM,
              p_display_location => apex_error.c_inline_in_notification );
            RAISE;
        END;

        INSERT INTO PurchaseDetails (
          PurchaseID,
          ProductID,
          RequestItemID,  -- Link back to the original request item
          Quantity,
          Price,
          Unit,
          ExpiryDate
          -- CurrencyID for item? -- Current design assumes single currency from Purchases table.
        ) VALUES (
          l_purchase_id,
          l_product_id,
          l_request_item_id,
          l_quantity,
          l_price,
          l_unit,
          l_expiry_date
        );
      EXCEPTION
        WHEN OTHERS THEN
            -- If any error occurs during item processing, re-raise to trigger main rollback
            RAISE;
      END;
    END LOOP;
  ELSE
    -- No items were submitted. This might be acceptable or an error depending on business rules.
    -- If items are mandatory for a purchase, add validation at the beginning.
    NULL;
  END IF; -- End of g_f01 check

  -- 6. Calculate and update TotalAmount in Purchases table
  UPDATE Purchases
  SET TotalAmount = (SELECT SUM(NVL(pd.Quantity,0) * NVL(pd.Price,0))
                     FROM PurchaseDetails pd
                     WHERE pd.PurchaseID = l_purchase_id)
  WHERE PurchaseID = l_purchase_id;

  -- 7. Update Status in the original PurchaseRequests table
  UPDATE PurchaseRequests
  SET Status = l_request_status
  WHERE RequestID = l_request_id;

  -- 8. Commit the transaction
  COMMIT;

  -- 10. Show success message to the user
  apex_success.add_message (
    p_message => 'Purchase (ID: ' || l_purchase_id || ') created successfully. Purchase Request (ID: '|| l_request_id ||') status updated to ''' || l_request_status || '''.'
  );

EXCEPTION
  WHEN OTHERS THEN
    -- 9. Error handling with ROLLBACK
    ROLLBACK;

    l_err_msg := SQLERRM;

    apex_error.add_error (
      p_message          => 'Error processing purchase: ' || l_err_msg,
      p_display_location => apex_error.c_inline_in_notification );

    -- For debugging, you might want to include backtrace:
    -- logger.log_error('P10 Save Purchase Error: ' || l_err_msg || ' Backtrace: ' || dbms_utility.format_error_backtrace);
END;
/
