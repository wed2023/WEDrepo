-- Foreign Keys for Tickets table
ALTER TABLE Tickets ADD CONSTRAINT FK_Tickets_SubmittedByUser FOREIGN KEY (SubmittedByUserID) REFERENCES Users(UserID);
ALTER TABLE Tickets ADD CONSTRAINT FK_Tickets_TicketType FOREIGN KEY (TicketTypeID) REFERENCES TicketTypes(TypeID);
ALTER TABLE Tickets ADD CONSTRAINT FK_Tickets_TicketStatus FOREIGN KEY (TicketStatusID) REFERENCES TicketStatuses(StatusID);
ALTER TABLE Tickets ADD CONSTRAINT FK_Tickets_Priority FOREIGN KEY (PriorityID) REFERENCES Priorities(PriorityID);
ALTER TABLE Tickets ADD CONSTRAINT FK_Tickets_Department FOREIGN KEY (DepartmentID) REFERENCES Departments(DepartmentID) ON DELETE SET NULL;
ALTER TABLE Tickets ADD CONSTRAINT FK_Tickets_AssignedToUser FOREIGN KEY (AssignedToUserID) REFERENCES Users(UserID) ON DELETE SET NULL;

-- Foreign Key for Users table
-- Note: FK_Users_Role will be added later after Roles table is created.
ALTER TABLE Users ADD CONSTRAINT FK_Users_Department FOREIGN KEY (DepartmentID) REFERENCES Departments(DepartmentID) ON DELETE SET NULL;

-- Foreign Keys for TicketAttachments table
ALTER TABLE TicketAttachments ADD CONSTRAINT FK_TicketAttachments_Ticket FOREIGN KEY (TicketID) REFERENCES Tickets(TicketID) ON DELETE CASCADE;
ALTER TABLE TicketAttachments ADD CONSTRAINT FK_TicketAttachments_User FOREIGN KEY (UploadedByUserID) REFERENCES Users(UserID) ON DELETE SET NULL;

-- Foreign Keys for TicketComments table
ALTER TABLE TicketComments ADD CONSTRAINT FK_TicketComments_Ticket FOREIGN KEY (TicketID) REFERENCES Tickets(TicketID) ON DELETE CASCADE;
ALTER TABLE TicketComments ADD CONSTRAINT FK_TicketComments_User FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE SET NULL;

-- Reminder: Ensure that the referenced tables (Users, TicketTypes, TicketStatuses, Priorities, Departments, Tickets)
-- and their primary key columns are created before running this script.
-- The FK for Users.RoleID referencing a Roles table is intentionally omitted as per problem description.
