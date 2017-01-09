//
//  SettingsViewController.swift
//  KMNavigationBarTransition
//
//  Created by eony on 2016/1/9.
//  Copyright © 2016年 Maxwell Eony. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    // MARK: Constants
    
    struct Constants {
        struct TableViewCell {
            static let Identifier = "Cell"
        }
    }
    
    // MARK: Properties
    
    var colorsData: (colorsArray: [NavigationBarBackgroundViewColor], selectedIndex: Int?)!
    var configurationBlock: ((_ color: NavigationBarBackgroundViewColor) -> Void)!
    var titleText = ""
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        title = titleText
    }
    
}

// MARK: - Table view data source

extension SettingsViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return colorsData.colorsArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.TableViewCell.Identifier, for: indexPath)
        cell.textLabel?.text = colorsData.colorsArray[indexPath.row].rawValue
        cell.accessoryType = (indexPath.row == colorsData.selectedIndex) ? .checkmark : .none
        
        return cell
    }
    
}

// MARK: - Table view delegate

extension SettingsViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let selectedIndex = colorsData.selectedIndex {
            tableView.cellForRow(at: IndexPath(row: selectedIndex, section: 0))?.accessoryType = .none
        }
        colorsData.selectedIndex = indexPath.row
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        tableView.deselectRow(at: indexPath, animated: true)
        configurationBlock?(colorsData.colorsArray[indexPath.row])
    }
    
}
