import chatexchange.client, chatexchange.events
from html import unescape
from sys import stdin, stdout, stderr, exit

user,pw,room = input(),input(),input()
stderr.flush()
client = chatexchange.client.Client('stackexchange.com')
client.login(user,pw)
room = client.get_room(room)
room.join()
room.watch(lambda msg, client: (stdout.write("{} {} {}\n".format(msg.id, msg.user.name, unescape(msg.content))),stdout.flush()))
stderr.write("Py stackexchange: success\n")
stderr.flush()

try:
  for l in stdin:
    if len(l.strip()):
      room.send_message(l.replace('\\n', '\n').replace('\\\\', '\\'))
except:
  client.logout()
  stderr.write("logged out\n")
  stderr.flush()
  exit(1)

client.logout()
stderr.write("logged out\n")
stderr.flush()