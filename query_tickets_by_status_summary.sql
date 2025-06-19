SELECT
    TS.StatusName AS Status_Name,
    COUNT(T.TicketID) AS Number_Of_Tickets
FROM
    TicketStatuses TS
LEFT JOIN
    Tickets T ON TS.StatusID = T.TicketStatusID
GROUP BY
    TS.StatusID, TS.StatusName, TS.StatusOrder
ORDER BY
    TS.StatusOrder ASC, TS.StatusName ASC;
