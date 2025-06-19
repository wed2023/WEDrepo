SELECT
    TA.AttachmentID,
    TA.FileName,
    TA.FileSize,
    TA.UploadDate,
    U.FullName AS UploadedByUserFullName
FROM
    TicketAttachments TA
LEFT JOIN
    Users U ON TA.UploadedByUserID = U.UserID
WHERE
    TA.TicketID = :PXX_TICKET_ID
ORDER BY
    TA.UploadDate DESC;
