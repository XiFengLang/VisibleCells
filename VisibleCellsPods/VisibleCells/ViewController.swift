//
//  ViewController.swift
//  VisibleCells
//
//  Created by JK on 2021/12/11.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    
    @IBAction func visibleCellsButtonClicked(_ sender: Any) {
        let tableVC = TableViewController()
        navigationController?.pushViewController(tableVC, animated: true)
    }
    

}

