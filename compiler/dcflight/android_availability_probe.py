"""Generate native verifier methods through the ordinary Android API emitter."""
from .platforms.android_api import JavaValue


def probe(api, member, index):
    parameters = []
    receiver = None
    if member.kind != 'ctor' and not member.static:
        parameters.append(member.owner + ' receiver')
        receiver = JavaValue.reference('receiver', member.owner)
    arguments = []
    for number, parameter in enumerate(member.parameters):
        name = 'arg' + str(number)
        parameters.append(parameter.java_type + ' ' + name)
        arguments.append(JavaValue.reference(name, parameter.java_type))
    context='worker' if api.thread_requirement(member)=='worker' else 'main'
    expression = api.emit(member.id, arguments, receiver, execution_context=context).source
    # The method can be inspected without invoking SDK code or permission APIs.
    statement = expression + ';' if member.java_type == 'void' else member.java_type + ' value = ' + expression + ';'
    return 'public static void p' + str(index) + '(' + ', '.join(parameters) + ') throws Throwable { ' + statement + ' }'
