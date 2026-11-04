use libsql::{Database, Connection};

fn main() {
    let db = Database::open_memory().expect("Failed to open in-memory database");
    let conn = db.connect().expect("Failed to get connection");

    conn.execute(
        "CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)",
        (),
    ).expect("Failed to create table");

    conn.execute(
        "INSERT INTO test (value) VALUES (?)",
        ("hello",),
    ).expect("Failed to insert");

    conn.execute(
        "INSERT INTO test (value) VALUES (?)",
        ("world",),
    ).expect("Failed to insert");

    let mut rows = conn.query("SELECT id, value FROM test ORDER BY id", ()).expect("Failed to query");
    let mut results = Vec::new();
    while let Some(row) = rows.next().expect("Failed to iterate rows") {
        let id: i64 = row.get(0).expect("Failed to get id");
        let value: String = row.get(1).expect("Failed to get value");
        results.push((id, value));
    }

    assert_eq!(results.len(), 2);
    assert_eq!(results[0], (1, "hello".to_string()));
    assert_eq!(results[1], (2, "world".to_string()));

    println!("All tests passed!");
}