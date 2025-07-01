import Foundation

struct TempExample {
    let id: UUID
    let name: String
    let createdAt: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
    
    func displayInfo() -> String {
        return "ID: \(id), Name: \(name), Created: \(createdAt)"
    }
}

class TempManager {
    private var items: [TempExample] = []
    
    func addItem(name: String) {
        let item = TempExample(name: name)
        items.append(item)
    }
    
    func getAllItems() -> [TempExample] {
        return items
    }
    
    func removeAll() {
        items.removeAll()
    }
}