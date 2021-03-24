import XCTest
@testable import EWSLibrary

final class EWSLibraryTests: XCTestCase {
    
    func testShell() {
        let shell = Shell()
        XCTAssert(shell.outputOf(commandName: "echo", arguments: ["testing the shell"]) == "testing the shell\n")
    }
    
    func realTruesRandomizationTrial(trueProbability: Double) -> Double {
        let trialCount = 10_000
        var trueCount = 0
        for _ in 0..<trialCount {
            if randomBool(withTrueProbability: trueProbability) {
                trueCount += 1
            }
        }
        return Double(trueCount) / Double(trialCount)
    }
    
    func testAlwaysRandomization() {
        let testRun = realTruesRandomizationTrial(trueProbability: 1)
        //XCTAssertLessThan(fabs(testRun - 1), 0.0000001)
        XCTAssertEqual(testRun, 1)
    }
    
    func testNeverRandomization() {
        let testRun = realTruesRandomizationTrial(trueProbability: 0)
        //XCTAssertLessThan(fabs(testRun - 0), 0.0000001)
        XCTAssertEqual(testRun, 0)
    }

    func testSometimesRandomization() {
        for probability in [0.25, 0.5, 0.75] {
            let testRun = realTruesRandomizationTrial(trueProbability: probability)
            XCTAssertLessThan(fabs(testRun - probability), 0.02)
        }
    }
    
    func testXMLToDict() {
        let xmlString = "<ArrayOfString><string>Steps</string><string>Heart Rate</string><string>Systolic Blood Pressure</string><string>Diastolic Blood Pressure</string><string>Activity Summary</string><string>Resting Heart Rate</string><string>Walking Heart Rate Average</string><string>Distance Walking or Running</string><string>Daily Steps</string><string>Flights of Stairs Climbed</string><string>Exercise Time</string><string>VO2 Max</string><string>Stand Hours</string><string>Workouts</string><string>Heart Rate Variability (HRV)</string><string>Mindful Sessions</string><string>Height</string><string>Body Mass Index (BMI)</string><string>Body Fat Percentage</string><string>Body Mass (Weight)</string><string>Lean Body Mass</string><string>Waist Circumference</string><string>Blood Glucose</string><string>Number of Times Fallen</string><string>Vital Signs</string><string>Medications</string><string>Procedures</string><string>Lab Results</string><string>Immunizations</string><string>Conditions</string><string>Allergies</string></ArrayOfString>"
        let xmlData = xmlString.data(using: .utf8)!
        let parser = XMLtoDictionary(xmlData: xmlData)
        let fart = parser.dictionary()
    }
    
    func testXMLToDict2() {
        let xmlString =
        """
        <?xml version="1.0" encoding="utf-8" ?>
        <StudyDashboardConfiguration  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <Sections>
              <Section>
                    <Components>
                      <Component xsi:type="WebVisualization" VisualizationKey="RURAL.Dashboard" />
                  </Components>
              </Section>
            </Sections>
          <WatchComponents></WatchComponents>
          <StudyDetailComponents></StudyDetailComponents>
              <CustomTabs>
            <Tab Key="RURALDashboard" Type="Dashboard" Title="Dashboard" Image="Dashboard" RequireProjectEnrollment="true">
              <Properties>
                <Property Key="DashboardKey" Value="RURALDashboard"/>
              </Properties>
            </Tab>
            <Tab Key="RURALMyData" Type="Dashboard" Title="My Data" Image="Dashboard">
              <Properties>
                  <Property Key="DashboardKey" Value="RURALMyData"></Property>
              </Properties>
            </Tab>
          </CustomTabs>
          <TabDisplayPreferences>
            <TabDisplayPreference TabKey="Dashboard" PreferHidden="true"/>
          </TabDisplayPreferences>
          <ProjectDashboards>
            <ProjectDashboard Key="RURALDashboard">
              <Section>
                <Components>
                  <Component xsi:type="WebVisualization" VisualizationKey="RURAL.Dashboard" />
                </Components>
              </Section>
            </ProjectDashboard>
            <ProjectDashboard Key="RURALMyData">
              <Section>
                <Components>
                  <Component xsi:type="WebVisualization" VisualizationKey="myFHR.DeviceActivity"></Component>
                  <Component xsi:type="WebVisualization" VisualizationKey="myFHR.LabResults"></Component>
                  <Component xsi:type="WebVisualization" VisualizationKey="myFHR.Medications"></Component>
                  <Component xsi:type="WebVisualization" VisualizationKey="myFHR.Allergies"></Component>
                  <Component xsi:type="WebVisualization" VisualizationKey="myFHR.Reports"></Component>
                  <Component xsi:type="WebVisualization" VisualizationKey="myFHR.Conditions"></Component>
                  <Component xsi:type="WebVisualization" VisualizationKey="myFHR.Procedures"></Component>
                  <Component xsi:type="WebVisualization" VisualizationKey="RURAL.MyDataDashboard"></Component>
                  <Component xsi:type="WebVisualization" VisualizationKey="RURAL.LinkedAccounts" StudyRecordAuthorityCode="RK.849C8B59.RURAL"></Component>
                </Components>
              </Section>
            </ProjectDashboard>
          </ProjectDashboards>
          <ParameterizedVisualizations>
            <ParameterizedVisualization Name="RURAL.Dashboard" VisualizationKey="RURAL.Dashboard">
              <Parameter Key="FitbitProviderID">564</Parameter>
              <Parameter Key="NotificationPrefsSurvey">5bfcab29-7a52-ea11-aa80-dfd10ba912af</Parameter>
              <Parameter Key="StepGoalSurvey">b0ecb1a0-d9ea-e911-8183-e7f24f0e0048</Parameter>
            </ParameterizedVisualization>
            <ParameterizedVisualization Name="RURAL.LinkedAccounts" VisualizationKey="RURAL.LinkedAccounts">
              <Parameter Key="ConnectAppleHealthRecordsSurveyID">1728f75a-c6cd-ea11-aa9b-0afb9334277d</Parameter>
            </ParameterizedVisualization>
            <ParameterizedVisualization Name="RURAL.MyDataDashboard" VisualizationKey="RURAL.MyDataDashboard"></ParameterizedVisualization>
            <ParameterizedVisualization Name="RURAL.SetNotificationPref" VisualizationKey="RURAL.SetNotificationPref" />
          </ParameterizedVisualizations>
        </StudyDashboardConfiguration>
        """
        let xmlData = xmlString.data(using: .utf8)!
        let parser = XMLtoDictionary(xmlData: xmlData)
        let fart = parser.dictionary()
    }

    static var allTests = [
        ("testShell", testShell),
        ("testAlwaysRandomization", testAlwaysRandomization),
        ("testNeverRandomization", testNeverRandomization),
        ("testSometimeRandomization", testSometimesRandomization)
    ]
}
