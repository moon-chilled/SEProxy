import chatexchange.client, chatexchange.events
from sys import stdin, stdout, stderr, exit
from html import unescape

def cb(msg, client):
    import re
    if not isinstance(msg, chatexchange.events.MessagePosted): return
    c = msg.content.replace("\r\n", "\\n")
    c = re.sub(r'<a[^<>]*href="?(//[^"\s]*)["\s][^<>]*>', r'(https:\1) ', c)
    c = re.sub(r'<a[^<>]*href="?([^"\s]*)["\s][^<>]*>', r'(\1) ', c)
    c = re.sub(r'<i>|</i>', '_', c)
    c = re.sub(r'<b>|</b>', '*', c)
    c = re.sub(r'<br>', "\n", c)
    c = re.sub(r'</?pre>|</?code>', '`', c)
    c = re.sub(r'<[^<>]*>', '', c)
    c = unescape(c)
    stdout.write("{}|{}|{}\n".format(msg._message_id, msg.user.name, c))
    stdout.flush()


user,pw,roomname = input(),input(),input()
stderr.flush()
def doop():
    client = chatexchange.client.Client('stackexchange.com')
    client.login(user,pw)
    room = client.get_room(roomname)
    room.join()
    room.watch(cb)
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
