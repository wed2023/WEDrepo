SELECT
    D.DepartmentName AS Department_Name,
    COUNT(CASE WHEN TS.IsOpenStatus = 1 THEN T.TicketID ELSE NULL END) AS Open_Tickets,
    COUNT(CASE WHEN TS.IsOpenStatus = 0 THEN T.TicketID ELSE NULL END) AS Closed_Tickets,
    COUNT(T.TicketID) AS Total_Tickets
FROM
    Departments D
LEFT JOIN
    Tickets T ON D.DepartmentID = T.DepartmentID
LEFT JOIN
    TicketStatuses TS ON T.TicketStatusID = TS.StatusID
GROUP BY
    D.DepartmentID, D.DepartmentName
ORDER BY
    D.DepartmentName ASC;
