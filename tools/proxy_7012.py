import socket
import threading
import sys

def forward(src, dst):
    while True:
        try:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
        except Exception:
            break
    try:
        src.close()
    except Exception:
        pass
    try:
        dst.close()
    except Exception:
        pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('127.0.0.1', 7012))
        server.listen(10)
        print("Proxy listening on 127.0.0.1:7012 -> 7013", flush=True)
        while True:
            client, addr = server.accept()
            remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                remote.connect(('127.0.0.1', 7013))
                threading.Thread(target=forward, args=(client, remote), daemon=True).start()
                threading.Thread(target=forward, args=(remote, client), daemon=True).start()
            except Exception:
                client.close()
    except Exception as e:
        print("Error:", e, flush=True)

if __name__ == '__main__':
    main()
