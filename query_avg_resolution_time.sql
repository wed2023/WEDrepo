WITH TicketDurations AS (
    -- CTE to calculate the duration of each closed ticket in days
    SELECT
        T.TicketID,
        T.TicketTypeID,
        T.PriorityID,
        T.DepartmentID,
        (T.ClosedDate - T.SubmissionDate) AS Duration_In_Days -- Simple day difference
        -- For more precise calculation (e.g., excluding weekends or non-working hours),
        -- a more complex function would be needed here.
    FROM
        Tickets T
    WHERE
        T.ClosedDate IS NOT NULL
        AND T.SubmissionDate IS NOT NULL
        AND T.ClosedDate >= T.SubmissionDate -- Ensure logical date sequence
        AND T.TicketStatusID IN (SELECT StatusID FROM TicketStatuses WHERE IsOpenStatus = 0) -- Ensure it's a closed status
)
-- Main query to aggregate durations
SELECT
    'Overall Average' AS Grouping_Type,
    NULL AS Grouping_Value_ID,
    NULL AS Grouping_Value_Name,
    ROUND(AVG(TD.Duration_In_Days), 2) AS Avg_Resolution_Time_Days,
    COUNT(TD.TicketID) AS Total_Closed_Tickets_Calculated
FROM
    TicketDurations TD

UNION ALL

SELECT
    'By Ticket Type' AS Grouping_Type,
    TD.TicketTypeID AS Grouping_Value_ID,
    TT.TypeName AS Grouping_Value_Name,
    ROUND(AVG(TD.Duration_In_Days), 2) AS Avg_Resolution_Time_Days,
    COUNT(TD.TicketID) AS Total_Closed_Tickets_Calculated
FROM
    TicketDurations TD
JOIN
    TicketTypes TT ON TD.TicketTypeID = TT.TypeID
GROUP BY
    TD.TicketTypeID, TT.TypeName

UNION ALL

SELECT
    'By Priority' AS Grouping_Type,
    TD.PriorityID AS Grouping_Value_ID,
    P.PriorityName AS Grouping_Value_Name,
    ROUND(AVG(TD.Duration_In_Days), 2) AS Avg_Resolution_Time_Days,
    COUNT(TD.TicketID) AS Total_Closed_Tickets_Calculated
FROM
    TicketDurations TD
JOIN
    Priorities P ON TD.PriorityID = P.PriorityID
GROUP BY
    TD.PriorityID, P.PriorityName

UNION ALL

SELECT
    'By Department' AS Grouping_Type,
    TD.DepartmentID AS Grouping_Value_ID,
    D.DepartmentName AS Grouping_Value_Name,
    ROUND(AVG(TD.Duration_In_Days), 2) AS Avg_Resolution_Time_Days,
    COUNT(TD.TicketID) AS Total_Closed_Tickets_Calculated
FROM
    TicketDurations TD
JOIN
    Departments D ON TD.DepartmentID = D.DepartmentID
WHERE
    TD.DepartmentID IS NOT NULL -- Only include if department is assigned
GROUP BY
    TD.DepartmentID, D.DepartmentName

ORDER BY
    Grouping_Type ASC, Grouping_Value_Name ASC;
