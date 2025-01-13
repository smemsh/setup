#
# evaluates a string as a math expression
# snarfed from:
# https://stackoverflow.com/questions/2371436
#
# TODO: doesn't work with +5+5+5 even though it's a valid python expression
# (have to strip leading '+' prior to calling)
#
import ast
import operator as op

operators = {
    ast.Add:      op.add,
    ast.Sub:      op.sub,
    ast.Mult:     op.mul,
    ast.Div:      op.truediv,
    ast.Pow:      op.pow,
    ast.BitXor:   op.xor,
    ast.USub:     op.neg,
}

class FilterModule(object):
    def filters(self):
        return {'matheval': evaluate_math_expression}


def evaluate(node):

    if isinstance(node, ast.Num): # <number>
        return node.n
    elif isinstance(node, ast.BinOp): # <left> <operator> <right>
        return operators[type(node.op)](
            evaluate(node.left), evaluate(node.right))
    elif isinstance(node, ast.UnaryOp): # <operator> <operand> e.g., -1
        return operators[type(node.op)](
            evaluate(node.operand))
    else:
        raise TypeError(node)


def evaluate_math_expression(expr):
    return evaluate(ast.parse(expr, mode='eval').body)
