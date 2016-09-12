import XCTest
@testable import FluentPostgreSQL
import Fluent

class FluentPostgreSQLTests: XCTestCase {
    static let allTests = [
        ("testSaveAndFind", testSaveAndFind)
    ]

    private(set) var database: Fluent.Database!
    private(set) var driver: PostgreSQLDriver!

    override func setUp() {
        driver = PostgreSQLDriver.makeTestConnection()
        database = Database(driver: driver)
    }

    func testSaveAndFind() {
        try! driver.raw("DROP TABLE IF EXISTS users")
        try! driver.raw("CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(16), email VARCHAR(100))")

        var user = User(id: nil, name: "Vapor", email: "vapor@qutheory.io")
        User.database = database

        do {
            try user.save()
        } catch {
            XCTFail("Could not save: \(error)")
        }

        do {
            let found = try User.find(1)
            //XCTAssertEqual(found?.id?.string, user.id?.string)
            XCTAssertEqual(found?.name, user.name)
            XCTAssertEqual(found?.email, user.email)
        } catch {
            XCTFail("Could not find user: \(error)")
        }
    }
}
