import XCTest
@testable import AWIeffect

final class ReferenceGraphContractTests:XCTestCase {
    func testEveryPassHasOneResolvableSourceAndAValidTarget() {
        let all=ReferenceFragmentCatalog.all
        XCTAssertEqual(Set(all.map(\.id)).count,all.count)
        XCTAssertEqual(Set(all.map(\.sourceID)).count,all.count)
        for definition in all {
            let bindings=[0]+Array(1..<(definition.images.count+1))+definition.buffers.map(\.binding)+(definition.referenceBinding.map { [$0] } ?? [])
            XCTAssertEqual(Set(bindings).count,bindings.count,definition.name)
            let targets=Set(definition.buffers.map(\.name))
            var produced=Set<String>()
            for (index,target) in definition.passes.enumerated() {
                XCTAssertTrue(target.isEmpty || targets.contains(target),definition.name)
                if let source=definition.sourcePasses[index] { XCTAssertTrue(produced.contains(source),definition.name+" reads an unproduced stage") }
                if let source=definition.externalPasses[index] {
                    XCTAssertNotNil(ReferenceFragmentCatalog.bySourceID[source],definition.name+" has an unresolved native pass")
                }
                if !target.isEmpty { produced.insert(target) }
            }
            if !definition.passes.isEmpty { XCTAssertEqual(definition.passes.last,"") }
            if let key=definition.iterationParameter { XCTAssertTrue(definition.parameters.contains { $0.definition.id==key },definition.name+" has an unbound iteration count") }
            for parameter in definition.parameters {
                XCTAssertTrue((11..<definition.slots).contains(parameter.slot))
                XCTAssertTrue((0..<4).contains(parameter.component))
                XCTAssertGreaterThan(parameter.scalarScale,0)
            }
        }
    }
    func testNativePassGraphsAreAcyclicAndBounded() {
        func check(_ definition:ReferenceFragmentDefinition,ancestors:Set<String>,depth:Int) {
            guard !ancestors.contains(definition.id),depth<8 else { XCTFail("Recursive/deep native pass: "+definition.name);return }
            var next=ancestors;next.insert(definition.id)
            for source in definition.externalPasses.values {
                if let child=ReferenceFragmentCatalog.bySourceID[source] { check(child,ancestors:next,depth:depth+1) }
            }
        }
        for definition in ReferenceFragmentCatalog.all { check(definition,ancestors:[],depth:0) }
    }
}
