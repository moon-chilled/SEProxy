import chatexchange.client, chatexchange.events
from sys import stdin, stdout, stderr, exit

user,pw,roomname = input(),input(),input()
stderr.flush()
def doop():
    client = chatexchange.client.Client('stackexchange.com')
    client.login(user,pw)
    room = client.get_room(roomname)
    room.join()
    room.watch(lambda msg, client: ((stdout.write("{}|{}|{}\n".format(msg._message_id, msg.user.name, msg.content.replace("\r\n","\\n"))),stdout.flush()) if isinstance(msg, chatexchange.events.MessagePosted) else None))
    stderr.write("Py stackexchange: success\n")
    stderr.flush()
    
    for l in stdin:
      if len(l.strip()):
        room.send_message(l.replace('\\n', '\n').replace('\\\\', '\\'))
        with open("test.txt", "a") as fp:
            fp.write(l.replace('\\n', '\n').replace('\\\\', '\\'))
            fp.write("\n")

while True:
    try:
        doop()
    except:
        stderr.write("logged out.  Reconnecting...\n")
        stderr.flush()
        __import__('time').sleep(60)
