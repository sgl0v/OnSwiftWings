import Foundation
import UIKit
import Combine

public class MoviesViewController : UITableViewController {
    private let imageLoader = ImageLoader()
    private var movies = [Movie]()

    override public func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        loadMovies()
    }

    private func configureUI() {
        tableView.tableFooterView = UIView()
        tableView.allowsSelection = false
        tableView.register(MovieTableViewCell.self, forCellReuseIdentifier: "\(MovieTableViewCell.self)")
    }

    private func loadMovies(){
        let path = Bundle.main.path(forResource:"movies", ofType: "json")!
        let data = FileManager.default.contents(atPath: path)!
        movies = try! JSONDecoder().decode([Movie].self, from: data)
        tableView.reloadData()
    }

}

extension MoviesViewController {

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movies.count
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "\(MovieTableViewCell.self)") as! MovieTableViewCell
        cell.configure(with: movies[indexPath.row])
        return cell
    }
}
