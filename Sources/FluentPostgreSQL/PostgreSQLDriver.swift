import Fluent
import PostgreSQL

public class PostgreSQLDriver: Fluent.Driver {
    public var idKey: String = "id"
    public var database: PostgreSQL.Database

    /**
        Attempts to establish a connection to a PostgreSQL database engine.
        - host: May be either a host name or an IP address. Default is "localhost".
        - port: Port number for the TCP/IP connection. Default is 5432. Can't be 0.
        - dbname: Name of PostgreSQL database.
        - user: Login ID of the PostgreSQL user.
        - password: Password for user.
        - throws: `Error.cannotEstablishConnection` if the call to connection fails.
    */
    public init(
        host: String = "localhost",
        port: Int = 5432,
        dbname: String,
        user: String,
        password: String
    ) {

        self.database = PostgreSQL.Database(
            host: host,
            port: "\(port)",
            dbname: dbname,
            user: user,
            password: password
        )
    }

    /**
        Creates the driver from an already initialized database.
    */
    public init(_ database: PostgreSQL.Database) {
        self.database = database
    }

    /**
        Queries the database.
    */
    @discardableResult
    public func query<T: Entity>(_ query: Query<T>) throws -> Node {
        let serializer = PostgreSQLSerializer(sql: query.sql)
        let (statement, values) = serializer.serialize()

        // create a connection in case it
        // needs to be used twice to fetch
        // data about the query
        let connection = try database.makeConnection()

        // execute the main statement
        let result = try _execute(statement, values, connection)

        switch query.action {
        case .create:
            // fetch the last inserted value
            let lastval = try _execute("SELECT LASTVAL();", [], connection)

            // check if it contains an id
            if let id = lastval[0, "lastval"]?.int {
                // return the id to fluent to
                // be the model's new id
                return .number(.int(id))
            } else {
                // no id found, return whatever
                // the results are
                return result
            }
        case .count:
            // Get the first row and first column value as int
            // (which should be the count, otherwise use 0)
            let integer = result
                .nodeArray?.first?
                .nodeObject?.first?.1.int ?? 0
            return .number(.int(integer))
        default:
            // return the results of the query
            return result
        }
    }

    /**
        Creates the desired schema.
    */
    public func schema(_ schema: Schema) throws {
        let serializer = PostgreSQLSerializer(sql: schema.sql)
        let (statement, values) = serializer.serialize()

        _ = try _execute(statement, values)
    }

    /**
        Provides access to the underlying PostgreSQL database for running raw queries.
    */
    @discardableResult
    public func raw(_ raw: String, _ values: [Node]) throws -> Node {
        return try _execute(raw, values)
    }

    // MARK: Private

    private func _execute(_ raw: String, _ values: [Node] = [], _ conn: Connection? = nil) throws -> Node {
        let connection: Connection

        if let c = conn {
            connection = c
        } else {
            connection = try database.makeConnection()
        }

        let result = try database.execute(raw, values, on: connection).map { Node.object($0) }
        return .array(result)
    }
}
