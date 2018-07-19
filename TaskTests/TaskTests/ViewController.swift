//
//  ViewController.swift
//  TaskTests
//
//  Created by Gustavo Vergara Garcia on 12/07/18.
//  Copyright © 2018 Gustavo. All rights reserved.
//

import UIKit
import Task

class ViewController: UIViewController, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activiyIndicator: UIActivityIndicatorView!
    @IBOutlet weak var progressView: UIProgressView!
    
    let repoFacade = RepoFacade()
    
    var repos: [Repo] = [Repo]() {
        didSet {
            self.tableView?.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func getRepos() {
        let getReposTask = self.repoFacade.getRepositories()
            .return(in: .main)
        
        getReposTask.onProgress { progress in
            self.progressView.setProgress(Float(progress), animated: true)
        }
        
        getReposTask.onCompletion { response in
            self.progressView.isHidden = true
            self.progressView.setProgress(0, animated: false)
            self.activiyIndicator.stopAnimating()
        }
        getReposTask.onSuccess { self.repos = $0 }
        getReposTask.onFailure { error in
            self.repos = []
            let alertController = UIAlertController(title: "Erro", message: error.message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in alertController.dismiss(animated: true) }))
            self.present(alertController, animated: true)
        }
        
        getReposTask.resume()
        self.progressView.isHidden = false
        self.activiyIndicator.startAnimating()
    }
    
    // MARK: UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.repos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        
        cell.textLabel?.text = self.repos[indexPath.row].name
        
        return cell
    }
    
}

struct Repo: Codable {
    var id: Int
    var name: String
}

class RepoFacade {
    
    let repoDAO = RepoDAO()
    
    func getRepositories() -> HTTPTask<[Repo], ResponseError> {
//        guard 22 == 21 else {
//            return .init(completedWith: .init(result: .failure(ResponseError())))
//        }
        return self.repoDAO.getRepositories()
    }
    
}

class RepoDAO {
    
    func getRepositories() -> HTTPTask<[Repo], ResponseError> {
        let request = URLRequest(url: URL(string: "https://api.github.com/repositories")!)
        
        let task = HTTPTask<Data, Error>(withRequest: request)
            .mapSuccess(as: [Repo].self)
            .mapFailure({ _ in return ResponseError() })
        
        task.resume()
        
        return task
    }
    
}
