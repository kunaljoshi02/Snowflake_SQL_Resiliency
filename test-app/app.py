from flask import Flask, render_template_string, request
import pyodbc
import os

app = Flask(__name__)

HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>SQL Connectivity Tester</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
<div class="container mt-5">
    <h1>SQL Server Connectivity Tester</h1>
    <p class="text-muted">Test connectivity through App Gateway &rarr; PE &rarr; PLS &rarr; ILB &rarr; SQL Server</p>
    <hr>
    <form method="POST" action="/query">
        <div class="row mb-3">
            <div class="col-md-6">
                <label class="form-label">SQL Server Host (App Gateway Private IP)</label>
                <input type="text" class="form-control" name="host" value="{{ host or '' }}" placeholder="10.1.3.10" required>
            </div>
            <div class="col-md-2">
                <label class="form-label">Port</label>
                <input type="text" class="form-control" name="port" value="{{ port or '1433' }}">
            </div>
        </div>
        <div class="row mb-3">
            <div class="col-md-4">
                <label class="form-label">Username</label>
                <input type="text" class="form-control" name="username" value="{{ username or 'sqladmin' }}">
            </div>
            <div class="col-md-4">
                <label class="form-label">Password</label>
                <input type="password" class="form-control" name="password" value="{{ password or '' }}">
            </div>
        </div>
        <div class="mb-3">
            <label class="form-label">SQL Query</label>
            <textarea class="form-control" name="query" rows="3">{{ query or "SELECT name, state_desc FROM sys.databases" }}</textarea>
        </div>
        <button type="submit" class="btn btn-primary">Test Connection</button>
    </form>
    {% if result %}
    <hr>
    <div class="alert alert-{{ result.status }}">
        <strong>{{ result.title }}</strong><br>
        {{ result.message }}
    </div>
    {% if result.data %}
    <table class="table table-striped">
        <thead><tr>{% for col in result.columns %}<th>{{ col }}</th>{% endfor %}</tr></thead>
        <tbody>{% for row in result.data %}<tr>{% for val in row %}<td>{{ val }}</td>{% endfor %}</tr>{% endfor %}</tbody>
    </table>
    {% endif %}
    {% endif %}
</div>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)

@app.route('/query', methods=['POST'])
def query():
    host = request.form.get('host', '')
    port = request.form.get('port', '1433')
    username = request.form.get('username', '')
    password = request.form.get('password', '')
    sql_query = request.form.get('query', 'SELECT name FROM sys.databases')

    try:
        conn_str = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={host},{port};"
            f"UID={username};"
            f"PWD={password};"
            f"TrustServerCertificate=yes;"
            f"Connection Timeout=10;"
        )
        conn = pyodbc.connect(conn_str, timeout=10)
        cursor = conn.cursor()
        cursor.execute(sql_query)
        columns = [desc[0] for desc in cursor.description]
        data = [list(row) for row in cursor.fetchall()]
        conn.close()

        result = {
            'status': 'success',
            'title': 'Connection Successful!',
            'message': f'Connected to {host}:{port} - {len(data)} rows returned',
            'columns': columns,
            'data': data
        }
    except Exception as e:
        result = {
            'status': 'danger',
            'title': 'Connection Failed',
            'message': str(e),
            'columns': [],
            'data': []
        }

    return render_template_string(HTML_TEMPLATE, result=result,
                                  host=host, port=port, username=username,
                                  password=password, query=sql_query)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
