// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/test_utilities/function_ast_visitor.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../dart/resolution/driver_resolution.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(Dart2InferenceTest);
  });
}

/// Tests for Dart2 inference rules back-ported from FrontEnd.
///
/// https://github.com/dart-lang/sdk/issues/31638
@reflectiveTest
class Dart2InferenceTest extends DriverResolutionTest {
  test_bool_assert() async {
    var code = r'''
T f<T>(int _) => null;

main() {
  assert(f(1));
  assert(f(2), f(3));
}

class C {
  C() : assert(f(4)),
        assert(f(5), f(6));
}
''';
    addTestFile(code);
    await resolveTestFile();

    MethodInvocation invocation(String search) {
      return findNode.methodInvocation(search);
    }

    assertInvokeType(invocation('f(1));'), 'bool Function(int)');

    assertInvokeType(invocation('f(2)'), 'bool Function(int)');
    assertInvokeType(invocation('f(3)'), 'dynamic Function(int)');

    assertInvokeType(invocation('f(4)'), 'bool Function(int)');

    assertInvokeType(invocation('f(5)'), 'bool Function(int)');
    assertInvokeType(invocation('f(6)'), 'dynamic Function(int)');
  }

  test_bool_logical() async {
    var code = r'''
T f<T>() => null;

var v1 = f() || f(); // 1
var v2 = f() && f(); // 2

main() {
  var v1 = f() || f(); // 3
  var v2 = f() && f(); // 4
}
''';
    addTestFile(code);
    await resolveTestFile();

    void assertType(String prefix) {
      var invocation = findNode.methodInvocation(prefix);
      expect(invocation.staticInvokeType.toString(), 'bool Function()');
    }

    assertType('f() || f(); // 1');
    assertType('f(); // 1');
    assertType('f() && f(); // 2');
    assertType('f(); // 2');

    assertType('f() || f(); // 3');
    assertType('f(); // 3');
    assertType('f() && f(); // 4');
    assertType('f(); // 4');
  }

  test_bool_statement() async {
    var code = r'''
T f<T>() => null;

main() {
  while (f()) {} // 1
  do {} while (f()); // 2
  if (f()) {} // 3
  for (; f(); ) {} // 4
}
''';
    addTestFile(code);
    await resolveTestFile();

    void assertType(String prefix) {
      var invocation = findNode.methodInvocation(prefix);
      expect(invocation.staticInvokeType.toString(), 'bool Function()');
    }

    assertType('f()) {} // 1');
    assertType('f());');
    assertType('f()) {} // 3');
    assertType('f(); ) {} // 4');
  }

  test_closure_downwardReturnType_arrow() async {
    var code = r'''
void main() {
  List<int> Function() g;
  g = () => 42;
}
''';
    addTestFile(code);
    await resolveTestFile();

    Expression closure = findNode.expression('() => 42');
    expect(closure.staticType.toString(), 'List<int> Function()');
  }

  test_closure_downwardReturnType_block() async {
    var code = r'''
void main() {
  List<int> Function() g;
  g = () { // mark
    return 42;
  };
}
''';
    addTestFile(code);
    await resolveTestFile();

    Expression closure = findNode.expression('() { // mark');
    expect(closure.staticType.toString(), 'List<int> Function()');
  }

  test_compoundAssignment_index() async {
    addTestFile(r'''
int getInt() => 0;
num getNum() => 0;
double getDouble() => 0.0;

abstract class Test<T, U> {
  T operator [](String s);
  void operator []=(String s, U v);
}

void test1(Test<int, int> t) {
  var /*@type=int*/ v1 = t['x'] = getInt();
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=int*/ v4 = t['x'] ??= getInt();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=int*/ v7 = t['x'] += getInt();
  var /*@type=num*/ v8 = t['x'] += getNum();
  var /*@type=int*/ v10 = ++t['x'];
  var /*@type=int*/ v11 = t['x']++;
}

void test2(Test<int, num> t) {
  var /*@type=int*/ v1 = t['x'] = getInt();
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=double*/ v3 = t['x'] = getDouble();
  var /*@type=int*/ v4 = t['x'] ??= getInt();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=num*/ v6 = t['x'] ??= getDouble();
  var /*@type=int*/ v7 = t['x'] += getInt();
  var /*@type=num*/ v8 = t['x'] += getNum();
  var /*@type=double*/ v9 = t['x'] += getDouble();
  var /*@type=int*/ v10 = ++t['x'];
  var /*@type=int*/ v11 = t['x']++;
}

void test3(Test<int, double> t) {
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=double*/ v3 = t['x'] = getDouble();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=num*/ v6 = t['x'] ??= getDouble();
  var /*@type=int*/ v7 = t['x'] += getInt();
  var /*@type=num*/ v8 = t['x'] += getNum();
  var /*@type=double*/ v9 = t['x'] += getDouble();
  var /*@type=int*/ v10 = ++t['x'];
  var /*@type=int*/ v11 = t['x']++;
}

void test4(Test<num, int> t) {
  var /*@type=int*/ v1 = t['x'] = getInt();
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=num*/ v4 = t['x'] ??= getInt();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=num*/ v7 = t['x'] += getInt();
  var /*@type=num*/ v8 = t['x'] += getNum();
  var /*@type=num*/ v10 = ++t['x'];
  var /*@type=num*/ v11 = t['x']++;
}

void test5(Test<num, num> t) {
  var /*@type=int*/ v1 = t['x'] = getInt();
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=double*/ v3 = t['x'] = getDouble();
  var /*@type=num*/ v4 = t['x'] ??= getInt();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=num*/ v6 = t['x'] ??= getDouble();
  var /*@type=num*/ v7 = t['x'] += getInt();
  var /*@type=num*/ v8 = t['x'] += getNum();
  var /*@type=num*/ v9 = t['x'] += getDouble();
  var /*@type=num*/ v10 = ++t['x'];
  var /*@type=num*/ v11 = t['x']++;
}

void test6(Test<num, double> t) {
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=double*/ v3 = t['x'] = getDouble();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=num*/ v6 = t['x'] ??= getDouble();
  var /*@type=num*/ v7 = t['x'] += getInt();
  var /*@type=num*/ v8 = t['x'] += getNum();
  var /*@type=num*/ v9 = t['x'] += getDouble();
  var /*@type=num*/ v10 = ++t['x'];
  var /*@type=num*/ v11 = t['x']++;
}

void test7(Test<double, int> t) {
  var /*@type=int*/ v1 = t['x'] = getInt();
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=num*/ v4 = t['x'] ??= getInt();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=double*/ v7 = t['x'] += getInt();
  var /*@type=double*/ v8 = t['x'] += getNum();
  var /*@type=double*/ v10 = ++t['x'];
  var /*@type=double*/ v11 = t['x']++;
}

void test8(Test<double, num> t) {
  var /*@type=int*/ v1 = t['x'] = getInt();
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=double*/ v3 = t['x'] = getDouble();
  var /*@type=num*/ v4 = t['x'] ??= getInt();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=double*/ v6 = t['x'] ??= getDouble();
  var /*@type=double*/ v7 = t['x'] += getInt();
  var /*@type=double*/ v8 = t['x'] += getNum();
  var /*@type=double*/ v9 = t['x'] += getDouble();
  var /*@type=double*/ v10 = ++t['x'];
  var /*@type=double*/ v11 = t['x']++;
}

void test9(Test<double, double> t) {
  var /*@type=num*/ v2 = t['x'] = getNum();
  var /*@type=double*/ v3 = t['x'] = getDouble();
  var /*@type=num*/ v5 = t['x'] ??= getNum();
  var /*@type=double*/ v6 = t['x'] ??= getDouble();
  var /*@type=double*/ v7 = t['x'] += getInt();
  var /*@type=double*/ v8 = t['x'] += getNum();
  var /*@type=double*/ v9 = t['x'] += getDouble();
  var /*@type=double*/ v10 = ++t['x'];
  var /*@type=double*/ v11 = t['x']++;
}
''');
    await resolveTestFile();
    _assertTypeAnnotations();
  }

  test_compoundAssignment_prefixedIdentifier() async {
    await assertNoErrorsInCode(r'''
int getInt() => 0;
num getNum() => 0;
double getDouble() => 0.0;

class Test<T extends U, U> {
  T get x => null;
  void set x(U _) {}
}

void test1(Test<int, int> t) {
  var /*@type=int*/ v1 = t.x = getInt();
  var /*@type=num*/ v2 = t.x = getNum();
  var /*@type=int*/ v4 = t.x ??= getInt();
  var /*@type=num*/ v5 = t.x ??= getNum();
  var /*@type=int*/ v7 = t.x += getInt();
  var /*@type=num*/ v8 = t.x += getNum();
  var /*@type=int*/ v10 = ++t.x;
  var /*@type=int*/ v11 = t.x++;
}

void test2(Test<int, num> t) {
  var /*@type=int*/ v1 = t.x = getInt();
  var /*@type=num*/ v2 = t.x = getNum();
  var /*@type=double*/ v3 = t.x = getDouble();
  var /*@type=int*/ v4 = t.x ??= getInt();
  var /*@type=num*/ v5 = t.x ??= getNum();
  var /*@type=num*/ v6 = t.x ??= getDouble();
  var /*@type=int*/ v7 = t.x += getInt();
  var /*@type=num*/ v8 = t.x += getNum();
  var /*@type=double*/ v9 = t.x += getDouble();
  var /*@type=int*/ v10 = ++t.x;
  var /*@type=int*/ v11 = t.x++;
}

void test5(Test<num, num> t) {
  var /*@type=int*/ v1 = t.x = getInt();
  var /*@type=num*/ v2 = t.x = getNum();
  var /*@type=double*/ v3 = t.x = getDouble();
  var /*@type=num*/ v4 = t.x ??= getInt();
  var /*@type=num*/ v5 = t.x ??= getNum();
  var /*@type=num*/ v6 = t.x ??= getDouble();
  var /*@type=num*/ v7 = t.x += getInt();
  var /*@type=num*/ v8 = t.x += getNum();
  var /*@type=num*/ v9 = t.x += getDouble();
  var /*@type=num*/ v10 = ++t.x;
  var /*@type=num*/ v11 = t.x++;
}

void test8(Test<double, num> t) {
  var /*@type=int*/ v1 = t.x = getInt();
  var /*@type=num*/ v2 = t.x = getNum();
  var /*@type=double*/ v3 = t.x = getDouble();
  var /*@type=num*/ v4 = t.x ??= getInt();
  var /*@type=num*/ v5 = t.x ??= getNum();
  var /*@type=double*/ v6 = t.x ??= getDouble();
  var /*@type=double*/ v7 = t.x += getInt();
  var /*@type=double*/ v8 = t.x += getNum();
  var /*@type=double*/ v9 = t.x += getDouble();
  var /*@type=double*/ v10 = ++t.x;
  var /*@type=double*/ v11 = t.x++;
}

void test9(Test<double, double> t) {
  var /*@type=num*/ v2 = t.x = getNum();
  var /*@type=double*/ v3 = t.x = getDouble();
  var /*@type=num*/ v5 = t.x ??= getNum();
  var /*@type=double*/ v6 = t.x ??= getDouble();
  var /*@type=double*/ v7 = t.x += getInt();
  var /*@type=double*/ v8 = t.x += getNum();
  var /*@type=double*/ v9 = t.x += getDouble();
  var /*@type=double*/ v10 = ++t.x;
  var /*@type=double*/ v11 = t.x++;
}
''');
    _assertTypeAnnotations();
  }

  test_compoundAssignment_propertyAccess() async {
    var t1 = 'new Test<int, int>()';
    var t2 = 'new Test<int, num>()';
    var t5 = 'new Test<num, num>()';
    var t8 = 'new Test<double, num>()';
    var t9 = 'new Test<double, double>()';
    await assertNoErrorsInCode('''
int getInt() => 0;
num getNum() => 0;
double getDouble() => 0.0;

class Test<T extends U, U> {
  T get x => null;
  void set x(U _) {}
}

void test1() {
  var /*@type=int*/ v1 = $t1.x = getInt();
  var /*@type=num*/ v2 = $t1.x = getNum();
  var /*@type=int*/ v4 = $t1.x ??= getInt();
  var /*@type=num*/ v5 = $t1.x ??= getNum();
  var /*@type=int*/ v7 = $t1.x += getInt();
  var /*@type=num*/ v8 = $t1.x += getNum();
  var /*@type=int*/ v10 = ++$t1.x;
  var /*@type=int*/ v11 = $t1.x++;
}

void test2() {
  var /*@type=int*/ v1 = $t2.x = getInt();
  var /*@type=num*/ v2 = $t2.x = getNum();
  var /*@type=double*/ v3 = $t2.x = getDouble();
  var /*@type=int*/ v4 = $t2.x ??= getInt();
  var /*@type=num*/ v5 = $t2.x ??= getNum();
  var /*@type=num*/ v6 = $t2.x ??= getDouble();
  var /*@type=int*/ v7 = $t2.x += getInt();
  var /*@type=num*/ v8 = $t2.x += getNum();
  var /*@type=double*/ v9 = $t2.x += getDouble();
  var /*@type=int*/ v10 = ++$t2.x;
  var /*@type=int*/ v11 = $t2.x++;
}

void test5() {
  var /*@type=int*/ v1 = $t5.x = getInt();
  var /*@type=num*/ v2 = $t5.x = getNum();
  var /*@type=double*/ v3 = $t5.x = getDouble();
  var /*@type=num*/ v4 = $t5.x ??= getInt();
  var /*@type=num*/ v5 = $t5.x ??= getNum();
  var /*@type=num*/ v6 = $t5.x ??= getDouble();
  var /*@type=num*/ v7 = $t5.x += getInt();
  var /*@type=num*/ v8 = $t5.x += getNum();
  var /*@type=num*/ v9 = $t5.x += getDouble();
  var /*@type=num*/ v10 = ++$t5.x;
  var /*@type=num*/ v11 = $t5.x++;
}

void test8() {
  var /*@type=int*/ v1 = $t8.x = getInt();
  var /*@type=num*/ v2 = $t8.x = getNum();
  var /*@type=double*/ v3 = $t8.x = getDouble();
  var /*@type=num*/ v4 = $t8.x ??= getInt();
  var /*@type=num*/ v5 = $t8.x ??= getNum();
  var /*@type=double*/ v6 = $t8.x ??= getDouble();
  var /*@type=double*/ v7 = $t8.x += getInt();
  var /*@type=double*/ v8 = $t8.x += getNum();
  var /*@type=double*/ v9 = $t8.x += getDouble();
  var /*@type=double*/ v10 = ++$t8.x;
  var /*@type=double*/ v11 = $t8.x++;
}

void test9() {
  var /*@type=num*/ v2 = $t9.x = getNum();
  var /*@type=double*/ v3 = $t9.x = getDouble();
  var /*@type=num*/ v5 = $t9.x ??= getNum();
  var /*@type=double*/ v6 = $t9.x ??= getDouble();
  var /*@type=double*/ v7 = $t9.x += getInt();
  var /*@type=double*/ v8 = $t9.x += getNum();
  var /*@type=double*/ v9 = $t9.x += getDouble();
  var /*@type=double*/ v10 = ++$t9.x;
  var /*@type=double*/ v11 = $t9.x++;
}
''');
    _assertTypeAnnotations();
  }

  test_compoundAssignment_simpleIdentifier() async {
    await assertNoErrorsInCode(r'''
int getInt() => 0;
num getNum() => 0;
double getDouble() => 0.0;

class Test<T extends U, U> {
  T get x => null;
  void set x(U _) {}
}

class Test1 extends Test<int, int> {
  void test1() {
    var /*@type=int*/ v1 = x = getInt();
    var /*@type=num*/ v2 = x = getNum();
    var /*@type=int*/ v4 = x ??= getInt();
    var /*@type=num*/ v5 = x ??= getNum();
    var /*@type=int*/ v7 = x += getInt();
    var /*@type=num*/ v8 = x += getNum();
    var /*@type=int*/ v10 = ++x;
    var /*@type=int*/ v11 = x++;
  }
}

class Test2 extends Test<int, num> {
  void test2() {
    var /*@type=int*/ v1 = x = getInt();
    var /*@type=num*/ v2 = x = getNum();
    var /*@type=double*/ v3 = x = getDouble();
    var /*@type=int*/ v4 = x ??= getInt();
    var /*@type=num*/ v5 = x ??= getNum();
    var /*@type=num*/ v6 = x ??= getDouble();
    var /*@type=int*/ v7 = x += getInt();
    var /*@type=num*/ v8 = x += getNum();
    var /*@type=double*/ v9 = x += getDouble();
    var /*@type=int*/ v10 = ++x;
    var /*@type=int*/ v11 = x++;
  }
}

class Test5 extends Test<num, num> {
  void test5() {
    var /*@type=int*/ v1 = x = getInt();
    var /*@type=num*/ v2 = x = getNum();
    var /*@type=double*/ v3 = x = getDouble();
    var /*@type=num*/ v4 = x ??= getInt();
    var /*@type=num*/ v5 = x ??= getNum();
    var /*@type=num*/ v6 = x ??= getDouble();
    var /*@type=num*/ v7 = x += getInt();
    var /*@type=num*/ v8 = x += getNum();
    var /*@type=num*/ v9 = x += getDouble();
    var /*@type=num*/ v10 = ++x;
    var /*@type=num*/ v11 = x++;
  }
}

class Test8 extends Test<double, num> {
  void test8() {
    var /*@type=int*/ v1 = x = getInt();
    var /*@type=num*/ v2 = x = getNum();
    var /*@type=double*/ v3 = x = getDouble();
    var /*@type=num*/ v4 = x ??= getInt();
    var /*@type=num*/ v5 = x ??= getNum();
    var /*@type=double*/ v6 = x ??= getDouble();
    var /*@type=double*/ v7 = x += getInt();
    var /*@type=double*/ v8 = x += getNum();
    var /*@type=double*/ v9 = x += getDouble();
    var /*@type=double*/ v10 = ++x;
    var /*@type=double*/ v11 = x++;
  }
}

class Test9 extends Test<double, double> {
  void test9() {
    var /*@type=num*/ v2 = x = getNum();
    var /*@type=double*/ v3 = x = getDouble();
    var /*@type=num*/ v5 = x ??= getNum();
    var /*@type=double*/ v6 = x ??= getDouble();
    var /*@type=double*/ v7 = x += getInt();
    var /*@type=double*/ v8 = x += getNum();
    var /*@type=double*/ v9 = x += getDouble();
    var /*@type=double*/ v10 = ++x;
    var /*@type=double*/ v11 = x++;
  }
}
''');
    _assertTypeAnnotations();
  }

  test_compoundAssignment_simpleIdentifier_topLevel() async {
    await assertNoErrorsInCode(r'''
class A {}

class B extends A {
  B operator +(int i) => this;
}

B get topLevel => new B();

void set topLevel(A value) {}

main() {
  var /*@type=B*/ v = topLevel += 1;
}
''');
    _assertTypeAnnotations();
  }

  test_forIn_identifier() async {
    var code = r'''
T f<T>() => null;

class A {}

A aTopLevel;
void set aTopLevelSetter(A value) {}

class C {
  A aField;
  void set aSetter(A value) {}
  void test() {
    A aLocal;
    for (aLocal in f()) {} // local
    for (aField in f()) {} // field
    for (aSetter in f()) {} // setter
    for (aTopLevel in f()) {} // top variable
    for (aTopLevelSetter in f()) {} // top setter
  }
}''';
    addTestFile(code);
    await resolveTestFile();

    void assertType(String prefix) {
      var invocation = findNode.methodInvocation(prefix);
      expect(invocation.staticType.toString(), 'Iterable<A>');
    }

    assertType('f()) {} // local');
    assertType('f()) {} // field');
    assertType('f()) {} // setter');
    assertType('f()) {} // top variable');
    assertType('f()) {} // top setter');
  }

  test_forIn_variable() async {
    var code = r'''
T f<T>() => null;

void test(Iterable<num> iter) {
  for (var w in f()) {} // 1
  for (var x in iter) {} // 2
  for (num y in f()) {} // 3
}
''';
    addTestFile(code);
    await resolveTestFile();

    {
      var node = findNode.simple('w in');
      VariableElement element = node.staticElement;
      expect(node.staticType, typeProvider.dynamicType);
      expect(element.type, typeProvider.dynamicType);

      var invocation = findNode.methodInvocation('f()) {} // 1');
      expect(invocation.staticType.toString(), 'Iterable<dynamic>');
    }

    {
      var node = findNode.simple('x in');
      VariableElement element = node.staticElement;
      expect(node.staticType, typeProvider.numType);
      expect(element.type, typeProvider.numType);
    }

    {
      var node = findNode.simple('y in');
      VariableElement element = node.staticElement;

      expect(node.staticType, typeProvider.numType);
      expect(element.type, typeProvider.numType);

      var invocation = findNode.methodInvocation('f()) {} // 3');
      expect(invocation.staticType.toString(), 'Iterable<num>');
    }
  }

  test_forIn_variable_implicitlyTyped() async {
    var code = r'''
class A {}
class B extends A {}

List<T> f<T extends A>(List<T> items) => items;

void test(List<A> listA, List<B> listB) {
  for (var a1 in f(listA)) {} // 1
  for (A a2 in f(listA)) {} // 2
  for (var b1 in f(listB)) {} // 3
  for (A b2 in f(listB)) {} // 4
  for (B b3 in f(listB)) {} // 5
}
''';
    addTestFile(code);
    await resolveTestFile();

    void assertTypes(
        String vSearch, String vType, String fSearch, String fType) {
      var node = findNode.simple(vSearch);
      expect(node.staticType.toString(), vType);

      var invocation = findNode.methodInvocation(fSearch);
      expect(invocation.staticType.toString(), fType);
    }

    assertTypes('a1 in', 'A', 'f(listA)) {} // 1', 'List<A>');
    assertTypes('a2 in', 'A', 'f(listA)) {} // 2', 'List<A>');
    assertTypes('b1 in', 'B', 'f(listB)) {} // 3', 'List<B>');
    assertTypes('b2 in', 'A', 'f(listB)) {} // 4', 'List<A>');
    assertTypes('b3 in', 'B', 'f(listB)) {} // 5', 'List<B>');
  }

  test_implicitVoidReturnType_default() async {
    var code = r'''
class C {
  set x(_) {}
  operator []=(int index, double value) => null;
}
''';
    addTestFile(code);
    await resolveTestFile();

    ClassElement c = findElement.class_('C');

    PropertyAccessorElement x = c.accessors[0];
    expect(x.returnType, VoidTypeImpl.instance);

    MethodElement operator = c.methods[0];
    expect(operator.displayName, '[]=');
    expect(operator.returnType, VoidTypeImpl.instance);
  }

  test_implicitVoidReturnType_derived() async {
    var code = r'''
class Base {
  dynamic set x(_) {}
  dynamic operator[]=(int x, int y) => null;
}
class Derived extends Base {
  set x(_) {}
  operator[]=(int x, int y) {}
}''';
    addTestFile(code);
    await resolveTestFile();

    ClassElement c = findElement.class_('Derived');

    PropertyAccessorElement x = c.accessors[0];
    expect(x.returnType, VoidTypeImpl.instance);

    MethodElement operator = c.methods[0];
    expect(operator.displayName, '[]=');
    expect(operator.returnType, VoidTypeImpl.instance);
  }

  test_inferObject_whenDownwardNull() async {
    var code = r'''
int f(void Function(Null) f2) {}
void main() {
  f((x) {});
}
''';
    addTestFile(code);
    await resolveTestFile();

    var xNode = findNode.simple('x) {}');
    VariableElement xElement = xNode.staticElement;
    expect(xNode.staticType, typeProvider.objectType);
    expect(xElement.type, typeProvider.objectType);
  }

  test_listMap_empty() async {
    var code = r'''
var x = [];
var y = {};
''';
    addTestFile(code);
    await resolveTestFile();

    SimpleIdentifier x = findNode.expression('x = ');
    expect(x.staticType.toString(), 'List<dynamic>');

    SimpleIdentifier y = findNode.expression('y = ');
    expect(y.staticType.toString(), 'Map<dynamic, dynamic>');
  }

  test_listMap_null() async {
    var code = r'''
var x = [null];
var y = {null: null};
''';
    addTestFile(code);
    await resolveTestFile();

    SimpleIdentifier x = findNode.expression('x = ');
    expect(x.staticType.toString(), 'List<Null>');

    SimpleIdentifier y = findNode.expression('y = ');
    expect(y.staticType.toString(), 'Map<Null, Null>');
  }

  test_switchExpression_asContext_forCases() async {
    var code = r'''
class C<T> {
  const C();
}

void test(C<int> x) {
  switch (x) {
    case const C():
      break;
    default:
      break;
  }
}''';
    addTestFile(code);
    await resolveTestFile();

    var node = findNode.instanceCreation('const C():');
    expect(node.staticType.toString(), 'C<int>');
  }

  test_voidType_method() async {
    var code = r'''
class C {
  void m() {}
}
var x = new C().m();
main() {
  var y = new C().m();
}
''';
    addTestFile(code);
    await resolveTestFile();

    SimpleIdentifier x = findNode.expression('x = ');
    expect(x.staticType, VoidTypeImpl.instance);

    SimpleIdentifier y = findNode.expression('y = ');
    expect(y.staticType, VoidTypeImpl.instance);
  }

  test_voidType_topLevelFunction() async {
    var code = r'''
void f() {}
var x = f();
main() {
  var y = f();
}
''';
    addTestFile(code);
    await resolveTestFile();

    SimpleIdentifier x = findNode.expression('x = ');
    expect(x.staticType, VoidTypeImpl.instance);

    SimpleIdentifier y = findNode.expression('y = ');
    expect(y.staticType, VoidTypeImpl.instance);
  }

  void _assertTypeAnnotations() {
    var code = result.content;
    var unit = result.unit;

    var types = <int, String>{};
    {
      int lastIndex = 0;
      while (true) {
        const prefix = '/*@type=';
        int openIndex = code.indexOf(prefix, lastIndex);
        if (openIndex == -1) {
          break;
        }
        int closeIndex = code.indexOf('*/', openIndex + 1);
        expect(closeIndex, isPositive);
        types[openIndex] =
            code.substring(openIndex + prefix.length, closeIndex);
        lastIndex = closeIndex;
      }
    }

    unit.accept(FunctionAstVisitor(
      simpleIdentifier: (node) {
        Token comment = node.token.precedingComments;
        if (comment != null) {
          String expectedType = types[comment.offset];
          if (expectedType != null) {
            String actualType = node.staticType.toString();
            expect(actualType, expectedType, reason: '@${comment.offset}');
          }
        }
      },
    ));
  }
}
