from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>DevOps Project 1</h1><p>Containerised and shipped.</p>"

@app.route("/health")
def health():
    return jsonify({"status": "ok", "version": os.getenv("APP_VERSION", "dev")})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
