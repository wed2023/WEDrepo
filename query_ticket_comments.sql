SELECT
    TC.CommentID, -- It's good practice to select the ID for potential actions/links
    TC.CommentText,
    TC.CommentDate,
    U.FullName AS CommentByUserFullName,
    TC.IsInternal -- This can be used to conditionally display comments or style them
FROM
    TicketComments TC
LEFT JOIN
    Users U ON TC.UserID = U.UserID
WHERE
    TC.TicketID = :PXX_TICKET_ID
ORDER BY
    TC.CommentDate DESC;
