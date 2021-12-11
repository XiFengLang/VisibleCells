//
//  TableViewController.swift
//  VisibleCells
//
//  Created by JK on 2021/12/11.
//

import Foundation
import UIKit

class TableViewController: UITableViewController {
    private enum State {
        case normal
        case editing
    }
    
    private var selectedIndexPaths = Set<IndexPath>()
    private var state: State = .normal
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "tableView.visibleCells"
        view.backgroundColor = .white
        tableView.register(Cell.self, forCellReuseIdentifier: "Cell")
        
        changeRightBarButton(animated: false)
    }
    
    private func changeRightBarButton(animated: Bool) {
        let isEditing = state == .editing
        navigationItem.setRightBarButton(
            .init(title: isEditing ? "取消" : "编辑", style: .plain,
                  target: self, action: #selector(editButtonItemClicked)),
            animated: animated
        )
    }
    
    @objc private func editButtonItemClicked() {
        state = state == .normal ? .editing : .normal
        changeRightBarButton(animated: true)
        
        selectedIndexPaths.removeAll()
        let isEditing = state == .editing
        
        tableView.visibleCells.forEach {
            if let cell = $0 as? Cell {
                cell.markEditing(isEditing, selected: false, animated: true)
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? Cell else {
            fatalError("UITableView不能复用，请确认该Cell是否注册！")
        }
        cell.titleLabel.text = "section:\(indexPath.section)  row:\(indexPath.row)"
        
        let selected = selectedIndexPaths.contains(indexPath)
        let isEditing = state == .editing
        cell.markEditing(isEditing, selected: selected, animated: false)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        do {
            if selectedIndexPaths.contains(indexPath) {
                selectedIndexPaths.remove(indexPath)
            } else {
                selectedIndexPaths.insert(indexPath)
            }
            tableView.reloadRows(at: [indexPath], with: .none)
        }
        
        var mountedIndexPaths = [IndexPath]()
        for section in (0..<tableView.numberOfSections) {
            for row in (0..<tableView.numberOfRows(inSection: section)) {
                let indexPath = IndexPath(row: row, section: section)
                
                // 这些Cell都是通过执行tableView(_:cellForRowAt:)代理方法复用/初始化并添加到TableView上的
                // nil != tableView.indexPath(for: cell) 或 nil != tableView.cellForRow(at: indexPath)
                if nil != tableView.cellForRow(at: indexPath) {
                    mountedIndexPaths.append(indexPath)
                }
            }
        }
        
        let cells = tableView.subviews.filter({ $0 is Cell })
        let mountedCells = cells.filter { cell in
            let indexPath = tableView.indexPath(for: cell as! Cell)
            if cell.isHidden {
                // iOS12/13/14，TableView上隐藏的Cell，都还没执行tableView(_:cellForRowAt:)代理方法复用
                // 但是nil == tableView.indexPath(for: cell), 可通过Lookin插件看Cell.titleLabel.text
                
                // iOS15 TableView上隐藏的Cell，可能已经执行tableView(_:cellForRowAt:)代理方法复用
                // 即nil != tableView.indexPath(for: cell), 还可通过Lookin插件看Cell.titleLabel.text
                // 之所以说“可能”，就有出现3个隐藏Cell，但是有2个已经走代理方法，1个没走代理方法
                
                print("Cell已添加到tableView上，isHidden(\(true))，at indexPath:\(indexPath as Any)")
            }
            return nil != indexPath
        }
        
        do {
            // 等同 tableView.indexPathsForVisibleRows
            let visibleCells = tableView.visibleCells
            let visibleIndexPaths = visibleCells.compactMap { cell in
                tableView.indexPath(for: cell)
            }
            let subtracting = Set(mountedIndexPaths).subtracting(visibleIndexPaths)
            // MARK: - Maybe failed in iOS15
            assert(subtracting.isEmpty, "异常1")
            
            // MARK: - Maybe failed in iOS15
            assert(mountedCells.count == visibleCells.count, "异常1.1")
        }

        do {
            if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
                let subtracting = Set(mountedIndexPaths).subtracting(visibleIndexPaths)
                // MARK: - Maybe failed in iOS15
                assert(subtracting.isEmpty, "异常2")
            }
        }
        
        do {
            let subtracting1 = Set(mountedIndexPaths).subtracting(tableView.mountedIndexPaths)
            assert(subtracting1.isEmpty, "异常3.1")
            
            let indexPaths = tableView.mountedCells.compactMap { cell in
                tableView.indexPath(for: cell)
            }
            let subtracting2 = Set(mountedIndexPaths).subtracting(indexPaths)
            assert(subtracting2.isEmpty, "异常3.2")
        }
        
        
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            let subtracting = Set(mountedIndexPaths).subtracting(visibleIndexPaths)
            subtracting.enumerated().forEach {
                if let cell = tableView.cellForRow(at: $0.element),
                   tableView === cell.superview {
                    
                    print("Cell已添加到tableView上，isHidden(\(cell.isHidden)), section: \($0.element.section)  row: \($0.element.row)")
                } else {
                    assert(false, "异常")
                }
            }
        }
        
        print("Congratulations! 🎉")
    }
}

class Cell: UITableViewCell {
    let titleLabel = UILabel()
    private let stateLabel = UILabel()
    private let checkView = UIView()
    private var checkViewLeadingConstraint: NSLayoutConstraint?
    private var titleLabelLeadingConstraint: NSLayoutConstraint?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(checkView)
        checkView.backgroundColor = .white
        checkView.layer.cornerRadius = 10
        checkView.layer.borderWidth = 1
        checkView.layer.borderColor = UIColor.black.cgColor
        checkView.isHidden = true
        
        checkView.translatesAutoresizingMaskIntoConstraints = false
        var constraint = checkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: -10)
        checkViewLeadingConstraint = constraint
        NSLayoutConstraint.activate([
            constraint,
            checkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 20),
            checkView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        contentView.addSubview(titleLabel)
        titleLabel.textColor = .black
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        constraint = titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15)
        titleLabelLeadingConstraint = constraint
        NSLayoutConstraint.activate([
            constraint,
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        
        contentView.addSubview(stateLabel)
        stateLabel.textColor = .black
        
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stateLabel.leadingAnchor.constraint(equalTo: self.titleLabel.trailingAnchor, constant: 5),
            stateLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func markEditing(_ editing: Bool, selected: Bool, animated: Bool) {
        stateLabel.text = editing ? " editing" : " normal"
        checkView.backgroundColor = selected ? .gray : .white
        if animated {
            let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut)
            checkView.isHidden = false
            checkView.alpha = editing ? 0.0 : 1.0
            
            animator.addAnimations { [weak self] in
                guard let self = self else { return }
                self.checkView.alpha = editing ? 1.0 : 0.0
                self.checkViewLeadingConstraint?.constant = editing ? 10 : -10
                self.titleLabelLeadingConstraint?.constant = editing ? 40 : 15
                self.contentView.layoutIfNeeded()
            }
            animator.addCompletion { [weak self] _ in
                guard let self = self else { return }
                self.checkView.alpha = 1.0
                self.checkView.isHidden = !editing
            }
            animator.startAnimation()
            
        } else {
            self.checkViewLeadingConstraint?.constant = editing ? 10 : -10
            self.titleLabelLeadingConstraint?.constant = editing ? 40 : 15
            contentView.layoutIfNeeded()
            checkView.alpha = 1.0
            checkView.isHidden = !editing
        }
    }
}

