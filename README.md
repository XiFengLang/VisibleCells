## tableView.visibleCells和indexPathsForVisibleRows在iOS15取不到完整数组

这个问题发生在iOS15，就一个很常见的需求：批量编辑列表，编辑状态可多选Cell，切换编辑状态时要动态刷新可视区域的Cell。  
> 粗略设计稿如下

![image.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fe37526163194f0d872e8da227e00505~tplv-k3u1fbpfcp-watermark.image?)

因为`tableView.reloadData()`不方便实现动效，想必大家首先会选择用`tableView.visibleCells`做局部动态刷新，我这几年就是这么做的。

```C
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
```

但是最近在iOS15设备上发现了奇奇怪怪的BUG，顶部和底部有个别Cell没有被刷新状态，滚动后就露出了马脚，有个别Cell保留了切换之前的状态。而这个问题不会在iOS14及以下系统出现，只在iOS15上出现。问题的表现可以看下面的动图，或者克隆仓库跑代码看看。

![ScreenRecording.mov.gif](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/d23a2d57b03f40228231974f031273b9~tplv-k3u1fbpfcp-watermark.image?)

排查一遍代码后并没有发现什么问题，最后借助[lookin](https://lookin.work/)调试UI才发现了问题。如下图所示，在屏幕的外面还有2-3个隐藏的Cell（iOS15一般是2个，iOS14及以下系统一般是1个），但是`tableView.visibleCells`取到的Cell都是那些没隐藏的(可视区域内的)Cell，不包括其它几个隐藏的Cell。而实际上这几个隐藏的Cell**可能**已经添加到了TableView上，并且代理方法`tableView(_:cellForRowAt:)`已经执行到对应的`IndexPath`，只是隐藏状态没有显示出现罢了。

比如截图(iOS15的)中的`section: 1 row: 4`和`section: 3 row: 3`，刚好位于屏幕的顶部和底部外边，iOS14及以下系统也有类似的准备机制，会在外边提前准备一个隐藏的Cell用于显示，但在iOS15这个动作似乎提前执行了。在iOS14及以下系统，这些隐藏的Cell，`tableView(_:cellForRowAt:)`还没执行到响应的`IndexPath`，`cell`和`indexPath`是没有关联的；而在iOS15，屏幕顶部和底部外边的2个隐藏Cell，很有可能已经绑定了`IndexPath`，也就是`tableView(_:cellForRowAt:)`可能已经执行到响应的`IndexPath`，`nil != tableView.indexPath(for: cell) && nil != tableView.cellForRow(at: indexPath)`。

![20211211135425.jpg](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/3c5dc8dbf53c4e9eb15be6bfe3d7812b~tplv-k3u1fbpfcp-watermark.image?)

![20211211135803.jpg](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/c8c9dd129b574196a1c594db90986833~tplv-k3u1fbpfcp-watermark.image?)

为此我在`tableView(_:didSelectRowAt:)`方法中加了一些断言，来测试这些隐藏的Cell有没有绑定`IndexPath`、对比所有绑定`IndexPath`的Cell和`tableView.visibleCells`是否相同以及其它的断言判断，个别断言会在iOS15出现失败，但是在iOS14及以下系统不会出现任何的问题。

> 忽略 do {} ，加上只为了隔离代码，没其它目的

```C
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
            
            /// 这些Cell`可能`是通过执行`tableView(_:cellForRowAt:)`代理方法复用并添加到TableView上的
            /// 代理方法 `tableView(_:cellForRowAt:)` `可能`已经执行到对应的IndexPath，Cell数据已经更新
            /// `nil != tableView.indexPath(for: cell) && nil != tableView.cellForRow(at: indexPath)`
            ///
            if nil != tableView.cellForRow(at: indexPath) {
                mountedIndexPaths.append(indexPath)
            }
        }
    }
    
    let cells = tableView.subviews.filter({ $0 is Cell })
    let mountedCells = cells.filter { cell in
        let indexPath = tableView.indexPath(for: cell as! Cell)
        if cell.isHidden {
            /// iOS12/13/14，TableView上隐藏的Cell，`tableView(_:cellForRowAt:)`都还没执行到对应的IndexPath
            /// 即`nil != tableView.cellForRow(at: indexPath)`, 还可通过Lookin插件看Cell.titleLabel.text
            
            /// iOS15 TableView上隐藏的Cell，`可能``tableView(_:cellForRowAt:)`已经执行到对应的IndexPath
            /// 即`nil != tableView.indexPath(for: cell) && nil != tableView.cellForRow(at: indexPath)`,
            /// 还可通过Lookin插件看Cell.titleLabel.text
            /// 之所以说“可能”，就有出现3个隐藏Cell，但是有2个已经走代理方法，1个没走代理方法
            
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
```

> * `tableView(_:cellForRowAt:)`已经执行到对应的IndexPath，数据已经更新
> * `cell.superView === tableView`
> * `nil != tableView.indexPath(for: cell)`
> * `nil != tableView.cellForRow(at: indexPath)`
> * `cell.isHidden == true`

通过测试后发现，在iOS15系统，`tableView.visibleCells` + `满足以上所有条件的Cells` 才是 `我们想要刷新的Cells`，iOS14及以下系统`tableView.visibleCells`就是`我们想要刷新的Cells`。

之所以说要满足所有条件，因为有个别隐藏的Cell并没有关联`indexPath`，也就是`tableView(_:cellForRowAt:)`还没有执行对应的`indexPath`，此时`nil == tableView.indexPath(for: cell)` and `nil == tableView.cellForRow(at: indexPath)`，这种Cell是TableView内部出于某种优化机制添加上的，我们不需要手动刷新这种Cell，因为还没走对应的`tableView(_:cellForRowAt:)`，以后滚动列表时会通过`tableView(_:cellForRowAt:)`刷新到这些Cell。

目前发现只会在屏幕的顶部或底部存在2个关联IndexPath且隐藏的Cell，所以只要在`indexPathsForVisibleRows`基础上往前新增1行，再往后加1行即可，也就是下面的`mountedIndexPaths`，具体可以看代码。

本文涉及到截图、视频、示例代码都已经放到Github上，感兴趣的可以下载下来跑一下项目。

> 目前只测试了iOS12、iOS13、iOS14和iOS15，iOS11及之前的系统没测。

```C
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
```