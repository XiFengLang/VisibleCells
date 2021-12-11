//
//  UITableView+Ext.swift
//  VisibleCells
//
//  Created by JK on 2021/12/11.
//

import UIKit

extension UITableView {
    private typealias CellTuple = (indexPath: IndexPath, cell: UITableViewCell)
    
    /// 返回上一个`已添加到TableView上的Cell和indexPath`
    private func mountedCell(before indexPath: IndexPath) -> CellTuple? {
        let sectionCount = numberOfSections
        guard sectionCount > 0 else { return nil }
        
        // 当前indexPath是本组的第1行，取前1组的最后1行
        if indexPath.row == 0, indexPath.section > 0 {
            for section in (0...indexPath.section - 1).reversed() {
                let rowCount = numberOfRows(inSection: section)
                if rowCount > 0 {
                    let targetIndexPath = IndexPath(row: rowCount - 1, section: section)
                    if let cell = cellForRow(at: targetIndexPath) {
                        return (targetIndexPath, cell)
                    }
                    return nil
                }
            }
        } else if indexPath.row > 0 {
            // 取本组的前面1行
            let targetIndexPath = IndexPath(row: indexPath.row - 1, section: indexPath.section)
            if let cell = cellForRow(at: targetIndexPath) {
                return (targetIndexPath, cell)
            }
        }
        return nil
    }
    
    /// 返回下一个`已添加到TableView上的Cell和indexPath`
    private func mountedCell(after indexPath: IndexPath) -> CellTuple? {
        let sectionCount = numberOfSections
        var rowCount = numberOfRows(inSection: indexPath.section)
        guard sectionCount > 0 && rowCount > 0 else { return nil }
        
        // 是本组最后1行，并且不是最后一组，取下1组的第1行
        if indexPath.row == rowCount - 1, indexPath.section < sectionCount - 1 {
            for section in (indexPath.section + 1..<sectionCount) {
                rowCount = numberOfRows(inSection: section)
                if rowCount > 0 {
                    let targetIndexPath = IndexPath(row: 0, section: section)
                    if let cell = cellForRow(at: targetIndexPath) {
                        return (targetIndexPath, cell)
                    }
                    return nil
                }
            }
        } else if indexPath.row < rowCount - 1 {
            // 取本组的下1行
            let targetIndexPath = IndexPath(row: indexPath.row + 1, section: indexPath.section)
            if let cell = cellForRow(at: targetIndexPath) {
                return (targetIndexPath, cell)
            }
        }
        return nil
    }
    
    /// 返回所有`已添加到TableView上的Cell的indexPath数组`，而不只是`indexPathsForVisibleRows`,
    /// 在`indexPathsForVisibleRows`基础上增加了`前后2个添加到TableView上的Cell的indexPath`
    ///
    /// `已添加到TableView上的Cell`等效`nil != tableView.cellForRow(at: indexPath)`
    ///
    ///     适用动态切换List编辑状态的场景，比如 动态刷新 所有已添加到TableView上的Cell，
    ///     如果不需要取局部的Cell做动态刷新，直接调TableView.reloadData()即可，省事又安全。
    ///     用`indexPathsForVisibleRows`和`visibleCells`只能取到可视区域内的Cell，
    ///     可能会漏掉顶部和底部2个未显示的Cell，
    ///     顶部和底部有2个Cell可能已经通过代理方法复用或初始化并添加到TableView上，只是没有显示出来，
    ///     漏掉的话就会导致拿不到这2个Cell调用动态刷新的方法，滚动时也不会再走代理方法刷新状态，
    ///     可能导致出现状态刷新后显示异常的BUG。
    ///
    /// - Returns: 返回的indexPath都能取到非空的Cell，即`nil != tableView.cellForRow(at: indexPath)`
    public var mountedIndexPaths: [IndexPath] {
        guard var indexPaths = indexPathsForVisibleRows, !indexPaths.isEmpty
        else { return [] }
        if #available(iOS 15.0, *) {
            if let previous = mountedCell(before: indexPaths.first!) {
                indexPaths.insert(previous.indexPath, at: 0)
            }
            
            if let next = mountedCell(after: indexPaths.last!) {
                indexPaths.append(next.indexPath)
            }
        }
        return indexPaths
    }
    
    /// 返回所有`已添加到TableView上的Cell数组`，而不只是`visibleCells`,
    /// 在`visibleCells`基础上增加了`前后2个添加到TableView上的Cell`
    ///
    /// `已添加到TableView上的Cell`等效`nil != tableView.cellForRow(at: indexPath)`
    ///
    ///     适用动态切换List编辑状态的场景，比如 动态刷新 所有已添加到TableView上的Cell，
    ///     如果不需要取局部的Cell做动态刷新，直接调TableView.reloadData()即可，省事又安全。
    ///     用`indexPathsForVisibleRows`和`visibleCells`只能取到可视区域内的Cell，
    ///     可能会漏掉顶部和底部2个未显示的Cell，
    ///     顶部和底部有2个Cell可能已经通过代理方法复用或初始化并添加到TableView上，只是没有显示出来，
    ///     漏掉的话就会导致拿不到这2个Cell调用动态刷新的方法，滚动时也不会再走代理方法刷新状态，
    ///     可能导致出现状态刷新后显示异常的BUG。
    ///
    /// - Returns: 返回的Cell都已经添加到TableView上，`tableView === cell.superView`
    public var mountedCells: [UITableViewCell] {
        var visibleCells = self.visibleCells
        guard !visibleCells.isEmpty else { return visibleCells }
        
        if #available(iOS 15.0, *) {
            if let indexPath = indexPath(for: visibleCells.first!),
               let previous = mountedCell(before: indexPath) {
                visibleCells.insert(previous.cell, at: 0)
            }
            
            if let indexPath = indexPath(for: visibleCells.last!),
               let next = mountedCell(after: indexPath) {
                visibleCells.append(next.cell)
            }
        }
        return visibleCells
    }
}

