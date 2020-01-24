//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport
import Combine

PlaygroundPage.current.needsIndefiniteExecution = true

struct User: Decodable {
    let id: Int
    let name: String
    let email: String
}

func getUsers(_ url: URL) -> AnyPublisher<Result<[User], Error>, Never> {
    return URLSession.shared
        .dataTaskPublisher(for: url)
        .map { $0.data }
        .decode(type: [User].self, decoder: JSONDecoder())
        .map { users in .success(users) }
        .catch { error in return Just(.failure(error)) }
        .handleEvents(receiveOutput: { output in
            print("response: \(output)\n")
        })
        .subscribe(on: DispatchQueue(label: "networking"))
        .receive(on: RunLoop.main)
        .shareReplay(1)
        .eraseToAnyPublisher()
}

let users = getUsers(URL(string: "https://jsonplaceholder.typicode.com/users")!)

let sub1 = users.sink(receiveValue: { value in
    print("subscriber1: \(value)\n")
})

let sub2 = users.sink(receiveValue: { value in
    print("subscriber2: \(value)\n")
})

