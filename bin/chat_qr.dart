import 'dart:convert';
import 'package:mysql_client/mysql_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'push_service.dart';
import 'config.dart';

List<Map<String, dynamic>> users = [];
List<Map<String, dynamic>> messages = [];

void main() async {
  Future<void> rebutMessages() async {
    if (messages.length > 10000) {
      messages.clear();
      httpServer();
    }
  }

  var handler = webSocketHandler((webSocket) {
    webSocket.stream.listen((message) async {
      var parsedMessage = jsonDecode(message);
      if (parsedMessage.containsKey('action') &&
          parsedMessage['action'] == 'join') {
        users.add({
          'webSocket': webSocket,
          'cid': parsedMessage['cid'],
        });
        List sortedMessages = List.from(
            messages.where((element) => element['cid'] == users.last['cid']));
        users.last['webSocket'].sink.add(jsonEncode(sortedMessages));
      } else {
        messages.add(parsedMessage);
        MySQLConnection sql = await MySQLConnection.createConnection(
            host: sqlhost,
            port: 3306,
            userName: sqlUser,
            password: sqlPasswors,
            databaseName: sqlDB);
        await sql.connect(timeoutMs: 999999999999);
        await sql.execute(
            "insert into messages (chat_id, uid, message) values (${parsedMessage['cid']}, '${parsedMessage['uid']}','${parsedMessage['text']}')");
        await sql.close();
        // Отправляем сообщение всем подписчикам, кроме отправителя
        for (var user in users) {
          // Фильтруем сообщения для отправки только тем, кто находится в одном чате
          var sortedMessages =
              messages.where((m) => m['cid'] == parsedMessage['cid']).toList();
          user['webSocket'].sink.add(jsonEncode(sortedMessages));
        }
      }
    });
  });
  MySQLConnection sql = await MySQLConnection.createConnection(
      host: sqlhost,
      port: 3306,
      userName: sqlUser,
      password: sqlPasswors,
      databaseName: sqlDB);
  await sql.connect(timeoutMs: 999999999999);
  final response = await sql.execute("select * from messages");
  for (var item in response.rows) {
    messages.add({
      'id': item.assoc()['id'],
      'cid': item.assoc()['chat_id'],
      'uid': item.assoc()['uid'],
      'text': item.assoc()['message'],
      'created_at': item.assoc()['created_at'],
    });
  }
  sql.close();
  shelf_io.serve(handler, baseUrl, portSocket).then((server) {
    print('Serving at ws://${server.address.host}:${server.port}');
  });
  httpServer();
}

void httpServer() async {
  Router router = Router();
  router.post('/createChat', (Request request) async {
    List users = [];
    var json = await request.readAsString();
    var data = await jsonDecode(json);
    bool created = false;

    if (data['type'] == 0 || data['type'] == '0') {
      print(data['users'][0]);
      print(data['users'][1]);
      try {
        MySQLConnection sql = await MySQLConnection.createConnection(
            host: sqlhost,
            port: 3306,
            userName: sqlUser,
            password: sqlPasswors,
            databaseName: sqlDB);
        await sql.connect(timeoutMs: 999999999999);
        final user1 = await sql.execute(
            "SELECT * FROM users_chat WHERE uid = '${data['users'][0]}'");
        final user2 = await sql.execute(
            "SELECT * FROM users_chat WHERE uid = '${data['users'][1]}'");

        IResultSet chatIdRow = await sql.execute(
            "SELECT uc1.chat_id FROM users_chat uc1 "
            "JOIN users_chat uc2 ON uc1.chat_id = uc2.chat_id "
            "WHERE uc1.uid = '${data['users'][0]}' AND uc2.uid = '${data['users'][1]}'");

        if (chatIdRow.rows.isNotEmpty) {
          var chatId = chatIdRow.rows.first.assoc()['chat_id'];
          created = true;
          return Response.ok(jsonEncode({'chat_id': chatId}));
        }
        sql.close();
      } catch (e) {
        print(e);
      }

      if (!created) {
        MySQLConnection sql = await MySQLConnection.createConnection(
            host: sqlhost,
            port: 3306,
            userName: sqlUser,
            password: sqlPasswors,
            databaseName: sqlDB);
        await sql.connect(timeoutMs: 999999999999);


        await sql.execute(
            "INSERT INTO chats (admin_uid, type) VALUES (${data['admin_uid']}, ${data['type']})");
        users = data['users'];
        var resul = await sql.execute(
          "SELECT * FROM chats",
        );
        String id = resul.rows.last.assoc()['id'] as String;
        int idInt = int.parse(id);
        for (var item in users) {
          var usersCount = await sql.execute(
            "SELECT * FROM users_chat",
          );
          String pid = usersCount.rows.last.assoc()['id'] as String;
          int uidInt = int.parse(pid);
          await sql.execute(
              "INSERT INTO users_chat (chat_id, uid) VALUES (${idInt + 1}, '$item')");
        }
        sql.close();
        return Response.ok(jsonEncode({'chat_id': idInt + 1}));
      }
      // } else {
      //   var resul = await sql.execute(
      //     "SELECT * FROM chats",
      //   );
      //   String id = resul.rows.last.assoc()['id'] as String;
      //   int idInt = int.parse(id);
      //   await sql.execute(
      //       "INSERT INTO chats (id, admin_uid, type) VALUES (${idInt + 1}, ${data['admin_uid']}, ${data['type']})");
      //
      //   List users = data['users'];
      //   for (var item in users) {
      //     var usersCount = await sql.execute(
      //       "SELECT * FROM users_chat",
      //     );
      //     String pid = usersCount.rows.last.assoc()['id'] as String;
      //     int uidInt = int.parse(pid);
      //     await sql.execute(
      //         "INSERT INTO users_chat (id, chat_id, uid) VALUES (${uidInt + 1}, ${idInt + 1}, '$item')");
      //   }
      //   return Response.ok(jsonEncode({'chat_id': idInt + 1}));
    } else if (data['type'] == 1 || data['type'] == '1') {
      MySQLConnection sql = await MySQLConnection.createConnection(
          host: sqlhost,
          port: 3306,
          userName: sqlUser,
          password: sqlPasswors,
          databaseName: sqlDB);
      await sql.connect(timeoutMs: 999999999999);
      print('type: 1');

      await sql.execute(
          "INSERT INTO chats (admin_uid, type, name) VALUES ('${data['uid']}', ${data['type']}, '${data['name']}')");
      var resul = await sql.execute(
        "SELECT * FROM chats",
      );
      String id = resul.rows.last.assoc()['id'] as String;
      int idInt = int.parse(id);
      await sql.execute(
          "INSERT INTO users_chat (chat_id, uid) VALUES ( ${idInt + 1}, '${data['uid']}')");
      sql.close();
      return Response.ok(jsonEncode({'chat_id': idInt + 1}));
    } else if (data['type'] == 2 || data['type'] == '2') {
      MySQLConnection sql = await MySQLConnection.createConnection(
          host: sqlhost,
          port: 3306,
          userName: sqlUser,
          password: sqlPasswors,
          databaseName: sqlDB);
      await sql.connect(timeoutMs: 999999999999);
      print('type: 2');

      await sql.execute(
          "INSERT INTO chats (admin_uid, type, name) VALUES ('${data['uid']}', ${data['type']}, '${data['name']}')");
      var resul = await sql.execute(
        "SELECT * FROM chats",
      );
      String id = resul.rows.last.assoc()['id'] as String;
      int idInt = int.parse(id);
      await sql.execute(
          "INSERT INTO users_chat (chat_id, uid) VALUES ( ${idInt + 1}, '${data['uid']}')");
      sql.close();
      return Response.ok(jsonEncode({'chat_id': idInt + 1}));
    }
    print('dddd');
  });
  router.post('/addUser', (Request request) async {
    MySQLConnection sql = await MySQLConnection.createConnection(
        host: sqlhost,
        port: 3306,
        userName: sqlUser,
        password: sqlPasswors,
        databaseName: sqlDB);
    await sql.connect(timeoutMs: 999999999999);
    var json = await request.readAsString();
    var data = await jsonDecode(json);
    await sql.execute(
        "insert into users_chat ( chat_id, uid) values (${data['chat_id']}, '${data['uid']}')");
    sql.close();
    return Response.ok('ok');
  });
  router.post('/sendPush', (Request request) async {
    var json = await request.readAsString();
    var data = await jsonDecode(json);
    globalPush(data['title'], data['body'], data['topic']);
    return Response.ok('send');
  });
  router.post('/deleteMessage', (Request request) async {
    var json = await request.readAsString();
    var data = await jsonDecode(json);
    print(data);

    // Удаление сообщения по id
    messages.removeWhere((message) => message['id'] == data['id']);

    print(messages);

    MySQLConnection sql = await MySQLConnection.createConnection(
      host: sqlhost,
      port: 3306,
      userName: sqlUser,
      password: sqlPasswors,
      databaseName: sqlDB,
    );

    await sql.connect(timeoutMs: 999999999999);
    await sql.execute("DELETE FROM messages WHERE id = ${data['id']}");
    await sql.close();

    return Response.ok('send');
  });
  router.post('/deleteUser', (Request request) async {
    var json = await request.readAsString();
    var data = await jsonDecode(json);
    MySQLConnection sql = await MySQLConnection.createConnection(
        host: sqlhost,
        port: 3306,
        userName: sqlUser,
        password: sqlPasswors,
        databaseName: sqlDB);
    await sql.connect(timeoutMs: 999999999999);
    if (data['type'] == '0') {
      await sql
          .execute("delete from users_chat where uid = '${data['opp_uid']}'");
    }
    await sql.execute(
        "delete from users_chat where uid='${data['uid']}' and chat_id=${data['chat_id']}");
    await sql.close();
    return Response.ok('send');
  });
  router.post('/getChats', (Request request) async {
    var json = await request.readAsString();
    var data = await jsonDecode(json);
    MySQLConnection sql = await MySQLConnection.createConnection(
        host: sqlhost,
        port: 3306,
        userName: sqlUser,
        password: sqlPasswors,
        databaseName: sqlDB);
    await sql.connect(timeoutMs: 999999999999);
    List chats = [];
    final response = await sql
        .execute("select * from users_chat where uid = '${data['uid']}'");
    for (var item in response.rows) {
      var data = item.assoc();
      final chatRow = await sql
          .execute("select * from chats where id = '${data['chat_id']}'");
      IResultSet opponents = await sql.execute(
          "select * from users_chat where chat_id = ${data['chat_id']}");
      List oponentsList = [];
      for (var item in opponents.rows) {
        oponentsList.add(
            {'uid': item.assoc()['uid'], 'type': item.assoc()['user_type']});
      }
      try {
        final lastMessageRow = await sql.execute(
            "select * from messages where chat_id = ${data['chat_id']}");
        chats.add({
          'id': data['chat_id'],
          'name': chatRow.rows.first.assoc()['name'],
          'type': chatRow.rows.first.assoc()['type'],
          'admin_uid': chatRow.rows.first.assoc()['admin_uid'],
          'message': lastMessageRow.rows.last.assoc()['message'],
          'opponents': oponentsList,
          'created_at': lastMessageRow.rows.last.assoc()['created_at'],
          'message_id': int.parse(lastMessageRow.rows.last.assoc()['id']!),
          'message_sender': lastMessageRow.rows.last.assoc()['uid'],
        });
      } catch (e) {
        chats.add({
          'id': data['chat_id'],
          'admin_uid': chatRow.rows.first.assoc()['admin_uid'],
          'name': chatRow.rows.first.assoc()['name'],
          'type': chatRow.rows.first.assoc()['type'],
          'opponents': oponentsList,
          'message': 'Нет сообщений' //lastMessageRow.rows.last.assoc()['text'],
        });
      }
    }
    print(chats);
    sql.close();
    chats
        .sort((a, b) => (b['message_id'] ?? 0).compareTo(a['message_id'] ?? 0));
    return Response.ok(jsonEncode(chats));
  });

  router.post('/getOpponents', (Request request) async {
    var json = await request.readAsString();
    var data = await jsonDecode(json);
    MySQLConnection sql = await MySQLConnection.createConnection(
        host: sqlhost,
        port: 3306,
        userName: sqlUser,
        password: sqlPasswors,
        databaseName: sqlDB);
    await sql.connect(timeoutMs: 999999999999);

    List opponents = [];
    IResultSet opponentsResult = await sql.execute(
        "select uid from users_chat where chat_id = '${data['chat_id']}'");
    for (var row in opponentsResult.rows) {
      opponents.add(row.assoc()['uid']);
    }

    sql.close();
    return Response.ok(jsonEncode(opponents));
  });

  serve(router, baseUrl, portHTPP);
}
