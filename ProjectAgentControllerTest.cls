@isTest
private class ProjectAgentControllerTest {
    
    // Helper method to create test Agent
    private static Agent__c createTestAgent(String name, DateTime lastAssigned) {
        Agent__c agent = new Agent__c(Name = name, Last_Assigned_Date_Time__c = lastAssigned);
        insert agent;
        return agent;
    }
    
    // Helper method to create test Project
    private static Project__c createTestProject(String name) {
        Project__c project = new Project__c(Name = name);
        insert project;
        return project;
    }
    
    // Helper method to create test Community
    private static Community__c createTestCommunity(String name, Id agentId) {
        Community__c community = new Community__c(Name = name, Agent__c = agentId);
        insert community;
        return community;
    }
    
    // Helper method to create assignment (if using it)
    private static Agent_Assignment__c createTestAssignment(Id agentId, Id projectId) {
        Agent_Assignment__c assignment = new Agent_Assignment__c(Agent__c = agentId, Projects__c = projectId);
        insert assignment;
        return assignment;
    }
    
    @isTest
    static void testGetAllAgents() {
        Agent__c agent = createTestAgent('Agent One', null);
        Test.startTest();
        List<Agent__c> agents = ProjectAgentController.getAllAgents();
        Test.stopTest();
    }
    
    @isTest
    static void testSearchProjectsByName() {
        createTestProject('Project Alpha');
        Test.startTest();
        List<Project__c> result = ProjectAgentController.searchProjectsByName('Alpha');
        Test.stopTest();
    }
    
    @isTest
    static void testGetAllProjects() {
        createTestProject('Project Beta');
        Test.startTest();
        List<Project__c> result = ProjectAgentController.getAllProjects();
        Test.stopTest();
    }
    
    @isTest
    static void testAssignAgentToProject() {
        Agent__c agent = createTestAgent('Agent Two', null);
        Project__c project = createTestProject('Project Gamma');
        
        Test.startTest();
        String result = ProjectAgentController.assignAgentToProject(project.Id, agent.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetNextAgentId() {
        Agent__c agent1 = createTestAgent('Oldest Agent', DateTime.now().addDays(-5));
        Agent__c agent2 = createTestAgent('Newer Agent', DateTime.now());
        
        Test.startTest();
        Id nextId = ProjectAgentController.getNextAgentId();
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetProjectAgentMap() {
        Project__c project = createTestProject('Project Delta');
        Agent__c agent = createTestAgent('Mapped Agent', null);
        agent.Project__c = project.Id;
        update agent;
        
        Test.startTest();
        Map<String, List<String>> mapResult = ProjectAgentController.getProjectAgentMap();
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetProjectAssignmentReport() {
        Agent__c agent = createTestAgent('Assignment Agent', null);
        Project__c project = createTestProject('Assigned Project');
        createTestAssignment(agent.Id, project.Id);
        
        Test.startTest();
        List<Agent_Assignment__c> report = ProjectAgentController.getProjectAssignmentReport();
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetAllCommunities() {
        Agent__c agent = createTestAgent('Community Agent', null);
        createTestCommunity('Test Community', agent.Id);
        
        Test.startTest();
        List<Community__c> communities = ProjectAgentController.getAllCommunities();
        Test.stopTest();
        
    }
    
    @isTest
    static void testSearchCommunitiesByName() {
        Agent__c agent = createTestAgent('Search Agent', null);
        createTestCommunity('Alpha Community', agent.Id);
        
        Test.startTest();
        List<Community__c> communities = ProjectAgentController.searchCommunitiesByName('Alpha');
        Test.stopTest();
        
    }
    
    @isTest
    static void testAssignAgentToCommunity() {
        Agent__c agent = createTestAgent('Assign Agent', null);
        Community__c community = new Community__c(Name = 'Community A');
        insert community;
        
        Test.startTest();
        String result = ProjectAgentController.assignAgentToCommunity(community.Id, agent.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetNextCommunityAgentId() {
        Agent__c agent1 = createTestAgent('Oldest Community Agent', DateTime.now().addDays(-10));
        Agent__c agent2 = createTestAgent('Recent Community Agent', DateTime.now());
        
        Test.startTest();
        Id nextAgentId = ProjectAgentController.getNextCommunityAgentId();
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetCommunityAgentMap() {
        Agent__c agent = createTestAgent('Community Mapped Agent', null);
        Community__c community = createTestCommunity('Mapped Community', agent.Id);
        
        Test.startTest();
        Map<String, List<String>> communityMap = ProjectAgentController.getCommunityAgentMap();
        Test.stopTest();
        
    }
    
    @isTest
    static void testAssignAgentToProjectExceptionHandling() {
        Test.startTest();
        try {
            ProjectAgentController.assignAgentToProject(null, null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testAssignAgentToCommunityExceptionHandling() {
        Test.startTest();
        try {
            ProjectAgentController.assignAgentToCommunity(null, null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
    @isTest
    static void testGetCommunityLocationFilters() {
        // Setup: Insert communities with Region, Sub_Region, Country
        Agent__c agent = createTestAgent('Location Filter Agent', null);
        
        List<Community__c> communities = new List<Community__c>{
            new Community__c(Name = 'Community X', Country__c = 'USA', Region__c = 'North America', Sub_Region__c = 'East', Agent__c = agent.Id),
                new Community__c(Name = 'Community Y', Country__c = 'USA', Region__c = 'North America', Sub_Region__c = 'West', Agent__c = agent.Id),
                new Community__c(Name = 'Community Z', Country__c = 'Canada', Region__c = 'North America', Sub_Region__c = 'Central', Agent__c = agent.Id)
                };
                    insert communities;
        
        Test.startTest();
        Map<String, List<String>> filters = ProjectAgentController.getCommunityLocationFilters();
        Test.stopTest();
        
    }
     @isTest
    static void testGetCommunityLocationPicklistValues() {
        Test.startTest();
        Map<String, List<String>> picklistValues = ProjectAgentController.getCommunityLocationPicklistValues();
        Test.stopTest();
    }
}