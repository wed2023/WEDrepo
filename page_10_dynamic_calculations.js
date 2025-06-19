/**
 * Oracle APEX JavaScript code for Page 10 Dynamic Calculations.
 * Handles subtotal and grand total calculations for purchase request items.
 */
$(document).ready(function() {

    // Helper function to parse float, returning 0 if NaN
    function parseFloatZero(value) {
        const parsed = parseFloat(value);
        return isNaN(parsed) ? 0 : parsed;
    }

    // Helper function to format currency (basic example)
    // In a real application, consider using a library like numeral.js or Intl.NumberFormat
    function formatCurrency(amount, currencyCode = '') {
        // This is a very basic formatter.
        // APEX typically has its own formatting functions or you can use JavaScript's Intl.NumberFormat
        const formattedAmount = amount.toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
        return currencyCode ? `${formattedAmount} ${currencyCode}` : formattedAmount;
    }

    /**
     * Calculates and updates the subtotal for a specific item.
     * @param {string} requestItemId The RequestItemID of the item.
     */
    function updateItemSubtotal(requestItemId) {
        if (!requestItemId) return;

        const quantityInput = $('#f02_' + requestItemId);
        const unitPriceInput = $('#f03_' + requestItemId);
        const subtotalDisplay = $('#item_subtotal_' + requestItemId);

        if (quantityInput.length && unitPriceInput.length && subtotalDisplay.length) {
            const quantity = parseFloatZero(quantityInput.val());
            const unitPrice = parseFloatZero(unitPriceInput.val());
            const subtotal = quantity * unitPrice;
            subtotalDisplay.text(formatCurrency(subtotal)); // Basic formatting
        }
        updateGrandTotal(); // Update grand total whenever a subtotal changes
    }

    /**
     * Calculates and updates the grand total for the invoice.
     */
    function updateGrandTotal() {
        let grandTotal = 0;
        $('.item-subtotal').each(function() {
            // Extract text, remove currency symbols/commas for calculation if more complex formatting is used
            const subtotalText = $(this).text().replace(/[^0-9.-]+/g,"");
            grandTotal += parseFloatZero(subtotalText);
        });

        const grandTotalDisplay = $('#grand_total_display');
        if (grandTotalDisplay.length) {
            const currencyCode = grandTotalDisplay.data('currency-code') || '';
            grandTotalDisplay.text(formatCurrency(grandTotal, currencyCode));
        }
    }

    // --- Event Binding ---

    // Use event delegation for dynamically added/managed APEX items
    // Bind to a static parent element, like the table or a container region
    // Assuming the table has an ID 'purchaseItemsTable' or is within a region with a static ID.
    // If not, $(document) can be used, but it's less performant.
    // Let's assume the table is wrapped in a div with class 'table-container' as per dynamic_content_p10.sql

    $('.table-container').on('input change', 'input[id^="f02_"], input[id^="f03_"]', function() {
        // Extract RequestItemID from the element's ID
        // ID is like "f02_REQUEST_ITEM_ID" or "f03_REQUEST_ITEM_ID"
        const parts = $(this).attr('id').split('_');
        const requestItemId = parts.length > 1 ? parts.slice(1).join('_') : null; // Handles IDs with underscores
        if (requestItemId) {
            updateItemSubtotal(requestItemId);
        }
    });

    // --- Initial Calculation on Page Load ---
    function initialCalculations() {
        // Iterate over each item's quantity or price field to trigger initial calculation
        $('input[id^="f02_"]').each(function() {
            const parts = $(this).attr('id').split('_');
            const requestItemId = parts.length > 1 ? parts.slice(1).join('_') : null;
            if (requestItemId) {
                updateItemSubtotal(requestItemId); // This will also call updateGrandTotal
            }
        });
        // If there were no items, updateGrandTotal ensures the total is displayed as 0.00
        if ($('input[id^="f02_"]').length === 0) {
            updateGrandTotal();
        }
    }

    // Perform initial calculations once the page and APEX items are fully loaded
    // Using a small timeout to ensure APEX items might be fully initialized if any
    // specific APEX behavior is involved, though direct binding is usually fine.
    setTimeout(initialCalculations, 100);

    // Expose functions to global scope if needed for calling from APEX dynamic actions (optional)
    // window.apexPage10 = {
    //     updateItemSubtotal,
    //     updateGrandTotal,
    //     initialCalculations
    // };

});
console.log('page_10_dynamic_calculations.js loaded and executed.');
