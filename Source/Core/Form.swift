//  Form.swift
//  Eureka ( https://github.com/xmartlabs/Eureka )
//
//  Copyright (c) 2016 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/// The delegate of the Eureka form.
public protocol FormDelegate : AnyObject {
    func sectionsHaveBeenAdded(_ sections: [Section], at: IndexSet)
    func sectionsHaveBeenRemoved(_ sections: [Section], at: IndexSet)
    func sectionsHaveBeenReplaced(oldSections: [Section], newSections: [Section], at: IndexSet)
    func rowsHaveBeenAdded(_ rows: [BaseRow], at: [IndexPath])
    func rowsHaveBeenRemoved(_ rows: [BaseRow], at: [IndexPath])
    func rowsHaveBeenReplaced(oldRows: [BaseRow], newRows: [BaseRow], at: [IndexPath])
    func valueHasBeenChanged(for row: BaseRow, oldValue: Any?, newValue: Any?)
}

// MARK: Form

/// The class representing the Eureka form.
open class Form {

    /// Defines the default options of the navigation accessory view.
    public static var defaultNavigationOptions = RowNavigationOptions.Enabled.union(.SkipCanNotBecomeFirstResponderRow)

    /// The default options that define when an inline row will be hidden. Applies only when `inlineRowHideOptions` is nil.
    public static var defaultInlineRowHideOptions = InlineRowHideOptions.FirstResponderChanges.union(.AnotherInlineRowIsShown)

    /// The options that define when an inline row will be hidden. If nil then `defaultInlineRowHideOptions` are used
    public var inlineRowHideOptions: InlineRowHideOptions?

    /// Which `UIReturnKeyType` should be used by default. Applies only when `keyboardReturnType` is nil.
    public static var defaultKeyboardReturnType = KeyboardReturnTypeConfiguration()

    /// Which `UIReturnKeyType` should be used in this form. If nil then `defaultKeyboardReturnType` is used
    public var keyboardReturnType: KeyboardReturnTypeConfiguration?

    /// This form's delegate
    public weak var delegate: FormDelegate?

    public required init() {}

    /**
     Returns the row at the given indexPath
     */
    public subscript(indexPath: IndexPath) -> BaseRow {
        return self[indexPath.section][indexPath.row]
    }

    /**
     Returns the row whose tag is passed as parameter. Uses a dictionary to get the row faster
     */
    public func rowBy<T>(tag: String) -> RowOf<T>? where T: Equatable{
        let row: BaseRow? = rowBy(tag: tag)
        return row as? RowOf<T>
    }

    /**
     Returns the row whose tag is passed as parameter. Uses a dictionary to get the row faster
     */
    public func rowBy<Row>(tag: String) -> Row? where Row: RowType{
        let row: BaseRow? = rowBy(tag: tag)
        return row as? Row
    }

    /**
     Returns the row whose tag is passed as parameter. Uses a dictionary to get the row faster
     */
    public func rowBy(tag: String) -> BaseRow? {
        return rowsByTag[tag]
    }

    /**
     Returns the section whose tag is passed as parameter.
     */
    public func sectionBy(tag: String) -> Section? {
        return kvoWrapper._allSections.filter({ $0.tag == tag }).first
    }

    /**
     Method used to get all the values of all the rows of the form. Only rows with tag are included.

     - parameter includeHidden: If the values of hidden rows should be included.

     - returns: A dictionary mapping the rows tag to its value. [tag: value]
     */
    public func values(includeHidden: Bool = false) -> [String: Any?] {
        if includeHidden {
            return getValues(for: allRows.filter({ $0.tag != nil }))
                .merging(getValues(for: allSections.filter({ $0 is BaseMultivaluedSection && $0.tag != nil }) as? [BaseMultivaluedSection]), uniquingKeysWith: {(_, new) in new })
        }
        return getValues(for: rows.filter({ $0.tag != nil }))
            .merging(getValues(for: allSections.filter({ $0 is BaseMultivaluedSection && $0.tag != nil }) as? [BaseMultivaluedSection]), uniquingKeysWith: {(_, new) in new })
    }

    /**
     Set values to the rows of this form

     - parameter values: A dictionary mapping tag to value of the rows to be set. [tag: value]
     */
    public func setValues(_ values: [String: Any?]) {
        for (key, value) in values {
            let row: BaseRow? = rowBy(tag: key)
            row?.baseValue = value
        }
    }

    /// The visible rows of this form
    public var rows: [BaseRow] { return flatMap { $0 } }

    /// All the rows of this form. Includes the hidden rows.
    public var allRows: [BaseRow] { return kvoWrapper._allSections.map({ $0.kvoWrapper._allRows }).flatMap { $0 } }

    /// All the sections of this form. Includes hidden sections.
    public var allSections: [Section] { return kvoWrapper._allSections }

    /**
     * Hides all the inline rows of this form.
     */
    public func hideInlineRows() {
        for row in self.allRows {
            if let inlineRow = row as? BaseInlineRowType {
                inlineRow.collapseInlineRow()
            }
        }
    }

    // MARK: Private

    var rowObservers = [String: [ConditionType: [Taggable]]]()
    var rowsByTag = [String: BaseRow]()
    var tagToValues = [String: Any]()
    lazy var kvoWrapper: KVOWrapper = { [unowned self] in return KVOWrapper(form: self) }()
}

extension Form: Collection {
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return kvoWrapper.sections.count }
}

extension Form: MutableCollection {

    // MARK: MutableCollectionType

    public subscript (_ position: Int) -> Section {
        get { return kvoWrapper.sections[position] as! Section }
        set {
            if position > kvoWrapper.sections.count {
                assertionFailure("Form: Index out of bounds")
            }

            if position < kvoWrapper.sections.count {
                let oldSection = kvoWrapper.sections[position]
                let oldSectionIndex = kvoWrapper._allSections.firstIndex(of: oldSection as! Section)!
                // Remove the previous section from the form
                kvoWrapper._allSections[oldSectionIndex].willBeRemovedFromForm()
                kvoWrapper._allSections[oldSectionIndex] = newValue
            } else {
                kvoWrapper._allSections.append(newValue)
            }

            kvoWrapper.sections[position] = newValue
            newValue.wasAddedTo(form: self)
        }
    }
    public func index(after i: Int) -> Int {
        return i+1 <= endIndex ? i+1 : endIndex
    }
    public func index(before i: Int) -> Int {
        return i > startIndex ? i-1 : startIndex
    }
    public var last: Section? {
        return reversed().first
    }

}

extension Form : RangeReplaceableCollection {

    // MARK: RangeReplaceableCollectionType

    public func append(_ formSection: Section) {
        kvoWrapper.sections.insert(formSection, at: kvoWrapper.sections.count)
        kvoWrapper._allSections.append(formSection)
        formSection.wasAddedTo(form: self)
    }

    public func append<S: Sequence>(contentsOf newElements: S) where S.Iterator.Element == Section {
        kvoWrapper.sections.addObjects(from: newElements.map { $0 })
        kvoWrapper._allSections.append(contentsOf: newElements)
        for section in newElements {
            section.wasAddedTo(form: self)
        }
    }

    public func replaceSubrange<C: Collection>(
        _ subRange: Range<Int>,
        with newElements: C
    ) where C.Iterator.Element == Section {
        for i in subRange.lowerBound..<subRange.upperBound {
            if let section = kvoWrapper.sections.object(at: i) as? Section {
                section.willBeRemovedFromForm()
                kvoWrapper._allSections.remove(at: kvoWrapper._allSections.firstIndex(of: section)!)
            }
        }
        kvoWrapper.sections.replaceObjects(
            in: NSRange(location: subRange.lowerBound, length: subRange.upperBound - subRange.lowerBound),
            withObjectsFrom: newElements.map { $0 }
        )
        kvoWrapper._allSections.insert(contentsOf: newElements, at: indexForInsertion(at: subRange.lowerBound))

        for section in newElements {
            section.wasAddedTo(form: self)
        }
    }

    public func replaceSubrangeInAllSections<C: Collection>(
        _ subRange: Range<Int>,
        with newElements: C
    ) where C.Iterator.Element == Section {
        // Remove subrange in all sections
        for i in subRange.reversed() where kvoWrapper._allSections.count > i {
            let removed = kvoWrapper._allSections.remove(at: i)
            removed.willBeRemovedFromForm()
        }

        kvoWrapper._allSections.insert(contentsOf: newElements, at: indexForInsertion(at: subRange.lowerBound))

        // Replace all visible sections by `kvoWrapper._allSections`, as hidden ones are being removed later anyway
        kvoWrapper.sections.replaceObjects(
            in: NSRange(location: 0, length: kvoWrapper.sections.count),
            withObjectsFrom: kvoWrapper._allSections
        )

        for section in newElements {
            section.wasAddedTo(form: self)
        }
    }

    public func removeAll(keepingCapacity keepCapacity: Bool = false) {
        // not doing anything with capacity

        let sections = kvoWrapper._allSections
        kvoWrapper.removeAllSections()

        for section in sections {
            section.willBeRemovedFromForm()
        }
    }

    public func removeAll(where shouldBeRemoved: (Section) throws -> Bool) rethrows {
        let indices = try kvoWrapper._allSections.enumerated()
            .filter { try shouldBeRemoved($0.element)}
            .map { $0.offset }

        var removedSections = [Section]()
        for index in indices.reversed() {
            removedSections.append(kvoWrapper._allSections.remove(at: index))
        }
        kvoWrapper.sections.removeObjects(in: removedSections)

        removedSections.forEach { $0.willBeRemovedFromForm() }
    }

    private func indexForInsertion(at index: Int) -> Int {
        guard index != 0 else { return 0 }

        let section = kvoWrapper.sections[index-1]
        if let i = kvoWrapper._allSections.firstIndex(of: section as! Section) {
            return i + 1
        }
        return kvoWrapper._allSections.count
    }

}

extension Form {

    // MARK: Private Helpers

    class KVOWrapper: NSObject {
        @objc dynamic private var _sections = NSMutableArray()
        var sections: NSMutableArray { return mutableArrayValue(forKey: "_sections") }
        var _allSections = [Section]()
        private weak var form: Form?

        init(form: Form) {
            self.form = form
            super.init()
            addObserver(self, forKeyPath: "_sections", options: [.new, .old], context:nil)
        }

        deinit {
            removeObserver(self, forKeyPath: "_sections")
            _sections.removeAllObjects()
            _allSections.removeAll()
        }

        func removeAllSections() {
            _sections = []
            _allSections.removeAll()
        }

        public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            let newSections = change?[NSKeyValueChangeKey.newKey] as? [Section] ?? []
            let oldSections = change?[NSKeyValueChangeKey.oldKey] as? [Section] ?? []
            guard let delegateValue = form?.delegate, let keyPathValue = keyPath, let changeType = change?[NSKeyValueChangeKey.kindKey] else { return }
            guard keyPathValue == "_sections" else { return }
            switch (changeType as! NSNumber).uintValue {
            case NSKeyValueChange.setting.rawValue:
                if newSections.count == 0 {
                    let indexSet = IndexSet(integersIn: 0..<oldSections.count)
                    delegateValue.sectionsHaveBeenRemoved(oldSections, at: indexSet)
                } else {
                    let indexSet = change![NSKeyValueChangeKey.indexesKey] as? IndexSet ?? IndexSet(integersIn: 0..<newSections.count)
                    delegateValue.sectionsHaveBeenAdded(newSections, at: indexSet)
                }
            case NSKeyValueChange.insertion.rawValue:
                let indexSet = change![NSKeyValueChangeKey.indexesKey] as! IndexSet
                delegateValue.sectionsHaveBeenAdded(newSections, at: indexSet)
            case NSKeyValueChange.removal.rawValue:
                let indexSet = change![NSKeyValueChangeKey.indexesKey] as! IndexSet
                delegateValue.sectionsHaveBeenRemoved(oldSections, at: indexSet)
            case NSKeyValueChange.replacement.rawValue:
                let indexSet = change![NSKeyValueChangeKey.indexesKey] as! IndexSet
                delegateValue.sectionsHaveBeenReplaced(oldSections: oldSections, newSections: newSections, at: indexSet)
            default:
                assertionFailure()
            }
        }
    }

    func dictionaryValuesToEvaluatePredicate() -> [String: Any] {
        return tagToValues
    }

    func addRowObservers(to taggable: Taggable, rowTags: [String], type: ConditionType) {
        for rowTag in rowTags {
            if rowObservers[rowTag] == nil {
                rowObservers[rowTag] = Dictionary()
            }
            if let _ = rowObservers[rowTag]?[type] {
                if !rowObservers[rowTag]![type]!.contains(where: { $0 === taggable }) {
                    rowObservers[rowTag]?[type]!.append(taggable)
                }
            } else {
                rowObservers[rowTag]?[type] = [taggable]
            }
        }
    }

    func removeRowObservers(from taggable: Taggable, rowTags: [String], type: ConditionType) {
        for rowTag in rowTags {
            guard let arr = rowObservers[rowTag]?[type], let index = arr.firstIndex(where: { $0 === taggable }) else { continue }
            rowObservers[rowTag]?[type]?.remove(at: index)
            if rowObservers[rowTag]?[type]?.isEmpty == true {
                rowObservers[rowTag] = nil
            }
        }
    }

    func nextRow(for row: BaseRow) -> BaseRow? {
        let allRows = rows
        guard let index = allRows.firstIndex(of: row) else { return nil }
        guard index < allRows.count - 1 else { return nil }
        return allRows[index + 1]
    }

    func previousRow(for row: BaseRow) -> BaseRow? {
        let allRows = rows
        guard let index = allRows.firstIndex(of: row) else { return nil }
        guard index > 0 else { return nil }
        return allRows[index - 1]
    }

    func hideSection(_ section: Section) {
        kvoWrapper.sections.remove(section)
    }

    func showSection(_ section: Section) {
        guard !kvoWrapper.sections.contains(section) else { return }
        guard var index = kvoWrapper._allSections.firstIndex(of: section) else { return }
        var formIndex = NSNotFound
        while formIndex == NSNotFound && index > 0 {
            index = index - 1
            let previous = kvoWrapper._allSections[index]
            formIndex = kvoWrapper.sections.index(of: previous)
        }
        kvoWrapper.sections.insert(section, at: formIndex == NSNotFound ? 0 : formIndex + 1 )
    }
	
	var containsMultivaluedSection: Bool {
		return kvoWrapper._allSections.contains { $0 is BaseMultivaluedSection }
	}

    public func getValues(for rows: [BaseRow]) -> [String: Any?] {
        return rows.reduce([String: Any?]()) {
            var result = $0
            result[$1.tag!] = $1.baseValue
            return result
        }
    }

    public func getValues(for multivaluedSections: [BaseMultivaluedSection]?) -> [String: [Any?]] {
        return multivaluedSections?.reduce([String: [Any?]]()) {
            var result = $0
            result[$1.tag!] = $1.values()
            return result
            } ?? [:]
    }

}

extension Form {

    @discardableResult
    public func validate(includeHidden: Bool = false, includeDisabled: Bool = true, quietly: Bool = false) -> [ValidationError] {
        let rowsWithHiddenFilter = includeHidden ? allRows : rows
        let rowsWithDisabledFilter = includeDisabled ? rowsWithHiddenFilter : rowsWithHiddenFilter.filter { $0.isDisabled != true }
        
        return rowsWithDisabledFilter.reduce([ValidationError]()) { res, row in
            var res = res
            res.append(contentsOf: row.validate(quietly: quietly))
            return res
        }
    }
    
    // Reset rows validation
    public func cleanValidationErrors(){
        allRows.forEach { $0.cleanValidationErrors() }
    }
}

