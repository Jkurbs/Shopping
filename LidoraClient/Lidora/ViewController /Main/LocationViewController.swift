//
//  LocationViewController.swift
//  Lidora
//
//  Created by Kerby Jean on 9/6/20.
//

import UIKit
import MapKit


class LocationViewController: UIViewController {
    
    var tableView: UITableView!
    var searchBar = UISearchBar()
    var searchCompleter = MKLocalSearchCompleter()
    var searchResults = [MKLocalSearchCompletion]()
    var currentAddress: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
    }
    
    func setupViews() {
        view.backgroundColor = .white
        self.title = "Change location"
        
        let doneButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        doneButtonItem.isEnabled = false
        navigationItem.rightBarButtonItem = doneButtonItem
        
        searchCompleter.delegate = self

        searchBar.frame = CGRect(x: 0, y: 60, width: view.frame.width, height: 60)
        searchBar.searchBarStyle = .prominent
        searchBar.placeholder = "Enter a new address"
        searchBar.sizeToFit()
        searchBar.isTranslucent = false
        searchBar.backgroundImage = UIImage()
        searchBar.delegate = self
        view.addSubview(searchBar)

        navigationController?.navigationBar.tintColor = .darkText
        
        tableView = UITableView(frame: CGRect(x: 0, y: 120, width: view.frame.width, height: view.frame.height - 60), style: .plain)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
    }
    
    @objc func done() {
        
    }
}

extension LocationViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchCompleter.queryFragment = searchText
    }
}



extension LocationViewController: MKLocalSearchCompleterDelegate {
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        tableView.reloadData()
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("An error occured MKLocalSearchCompleter: ", error)
    }
}


extension LocationViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return searchResults.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
        let originalImage = UIImage(systemName: "location")
        let image = originalImage?.withTintColor(.gray, renderingMode: .alwaysOriginal)
        cell.imageView?.image = image
        if indexPath.section == 0 {
            cell.textLabel?.text = self.currentAddress
        } else {
            let searchResult = searchResults[indexPath.row]
            cell.textLabel?.text = searchResult.title
            cell.detailTextLabel?.text = searchResult.subtitle
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 60.0
        }
        return 60.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            
        } else {
            let selectedResult = self.searchResults[indexPath.row]
            print("SELECTED RESULT: ", selectedResult.subtitle)
        }
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
}
