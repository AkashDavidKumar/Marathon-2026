
import logging
import json
import subprocess
import tempfile
import os
import time
import re

logger = logging.getLogger(__name__)

# === CONFIGURATION ===
# In production, set this to 'docker' or 'judge0'
EXECUTION_MODE = os.getenv('EXECUTION_MODE', 'local_secure') 

# === SECURITY WRAPPER ===
def validate_code_security(code, language):
    """
    Scans the user code for potentially malicious patterns.
    Returns: (is_safe: bool, error_message: str)
    """
    code_lower = code.lower()
    
    # 1. Global Blocklist
    # Block file system access, network access, and process management
    dangerous_globals = [
        'rm -rf', 'wget', 'curl', 'shutdown', 'reboot'
    ]
    for k in dangerous_globals:
        if k in code_lower:
             return False, f"Security Violation: '{k}' is prohibited."

    # 2. Python Specific
    if language == 'python':
        dangerous_py = [
            'import os', 'from os', 'import subprocess', 'import sys', 'import pty', 'import shutil', 
            'import requests', 'import urllib', 'import socket', 'import multiprocessing', 'import threading',
            'open(', 'exec(', 'eval(', '__import__', 'os.system', 'os.popen', 'os.walk', 'os.remove',
            'subprocess.run', 'subprocess.Popen', 'sys.modules'
        ]
        for keyword in dangerous_py:
            if keyword in code: # Case sensitive for Python imports mostly, but safer to check strict
                return False, f"Security Violation: usage of '{keyword}' is prohibited."

    # 3. Node.js Specific
    if language in ['javascript', 'nodejs', 'node']:
         dangerous_js = [
             'require("child_process")', "require('child_process')",
             'require("fs")', "require('fs')",
             'require("net")', "require('net')",
             'require("http")', "require('http')",
             'process.env', 'process.kill', 'process.exit', 'exec(', 'spawn('
         ]
         for keyword in dangerous_js:
             if keyword in code:
                 return False, f"Security Violation: usage of '{keyword}' is prohibited."

    # 4. C/C++ Specific
    if language in ['c', 'cpp']:
        dangerous_c = [
            'system(', 'fork(', 'popen(', 'execl(', 'execv(', 'remove(', 'rename(', 'fopen(', 'socket('
        ]
        for keyword in dangerous_c:
             if keyword in code:
                  return False, f"Security Violation: system call '{keyword}' is prohibited."

    return True, None

# === EXECUTION ENGINE ===

def execute_code_internal(code, language, input_str):
    """
    Facade for code execution. Dispatches to local sandbox or docker/external service.
    """
    # 1. Security Check (Always applied first)
    is_safe, violation_msg = validate_code_security(code, language)
    if not is_safe:
        return {'success': False, 'output': '', 'error': violation_msg}

    # 2. Dispatch
    if EXECUTION_MODE == 'local_secure':
        return execute_local_secure(code, language, input_str)
    elif EXECUTION_MODE == 'docker':
        return {'success': False, 'error': "Docker execution not yet implemented"}
    else:
        return {'success': False, 'error': "Unknown Execution Mode"}

def execute_local_secure(code, language, input_str):
    """
    Executes code locally using subprocess with strict timeouts and (where possible) limits.
    """
    input_str = str(input_str)
    
    # Common Resource Limits (Time in seconds)
    TIMEOUT_SEC = 2
    
    try:
        if language == 'python':
            return run_python(code, input_str, TIMEOUT_SEC)
        elif language in ['c', 'cpp']:
            return run_cpp(code, language, input_str, TIMEOUT_SEC)
        elif language == 'java':
            return run_java(code, input_str, TIMEOUT_SEC)
        elif language in ['javascript', 'node']:
            return run_node(code, input_str, TIMEOUT_SEC)
        else:
            return {'success': False, 'error': f"Language {language} not supported"}
            
    except Exception as e:
        logger.error(f"Execution Error: {e}")
        return {'success': False, 'error': "Internal Execution Error"}

def run_python(code, input_str, timeout):
    # Try 'python3' first (more standard on Linux/Render), then fallback to 'python'
    for cmd in ['python3', 'python']:
        try:
            # '-u' for unbuffered output
            p = subprocess.run(
                [cmd, '-u', '-c', code],
                input=input_str,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if p.returncode != 0:
                return {'success': False, 'output': p.stdout, 'error': p.stderr or "Runtime Error"}
            return {'success': True, 'output': p.stdout, 'error': None}
        except FileNotFoundError:
            continue
        except subprocess.TimeoutExpired:
            return {'success': False, 'output': '', 'error': "Time Limit Exceeded"}
        except Exception as e:
            return {'success': False, 'output': '', 'error': f"Python Execution Error: {str(e)}"}
            
    return {'success': False, 'output': '', 'error': "Python interpreter (python3/python) not found."}

def run_cpp(code, lang, input_str, timeout):
    compiler = 'gcc' if lang == 'c' else 'g++'
    ext = '.c' if lang == 'c' else '.cpp'
    
    with tempfile.TemporaryDirectory() as tmpdir:
        src_path = os.path.join(tmpdir, f'main{ext}')
        exe_path = os.path.join(tmpdir, 'main.exe')
        
        with open(src_path, 'w') as f:
            f.write(code)
            
        # Compile
        try:
            c_proc = subprocess.run(
                [compiler, src_path, '-o', exe_path],
                capture_output=True,
                text=True,
                timeout=5 # Compile timeout
            )
            if c_proc.returncode != 0:
                 return {'success': False, 'output': '', 'error': "Compilation Error:\n" + c_proc.stderr}
            warnings = c_proc.stderr # Capture warnings
        except Exception as e:
             return {'success': False, 'output': '', 'error': "Compiler not found or failed."}

        # Run
        try:
            r_proc = subprocess.run(
                [exe_path],
                input=input_str,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if r_proc.returncode != 0:
                return {'success': False, 'output': r_proc.stdout, 'error': r_proc.stderr or "Runtime Error", 'warnings': warnings}
            return {'success': True, 'output': r_proc.stdout, 'error': None, 'warnings': warnings}
        except subprocess.TimeoutExpired:
            return {'success': False, 'output': '', 'error': "Time Limit Exceeded"}

def run_java(code, input_str, timeout):
    # Extract public class name or default to 'Main'
    class_name_match = re.search(r'public\s+class\s+([a-zA-Z0-9_$]+)', code)
    class_name = class_name_match.group(1) if class_name_match else "Main"
    
    with tempfile.TemporaryDirectory() as tmpdir:
        src_path = os.path.join(tmpdir, f'{class_name}.java')

        with open(src_path, 'w') as f:
            f.write(code)
            
        # Compile
        try:
            # Find javac path
            javac_cmd = 'javac'
            # Check if javac is in common paths as fallback
            common_paths = [
                '/usr/bin/javac',
                '/usr/lib/jvm/java-11-openjdk-amd64/bin/javac',
                '/usr/lib/jvm/java-8-openjdk-amd64/bin/javac',
                '/usr/lib/jvm/java-11-amazon-corretto.x86_64/bin/javac',
                '/usr/local/bin/javac'
            ]
            
            # Simple check if javac is available in default path
            try:
                subprocess.run(['javac', '-version'], capture_output=True)
            except FileNotFoundError:
                for path in common_paths:
                    if os.path.exists(path):
                        javac_cmd = path
                        break

            c_proc = subprocess.run(
                [javac_cmd, src_path],
                capture_output=True,
                text=True,
                timeout=15 # Increased timeout for slow disks
            )
            if c_proc.returncode != 0:
                 return {'success': False, 'output': '', 'error': "Compilation Error:\n" + c_proc.stderr}
        except FileNotFoundError:
             return {'success': False, 'output': '', 'error': "Java Compiler (javac) not found. Please ensure JDK is installed."}
        except Exception as e:
             return {'success': False, 'output': '', 'error': f"Internal Compiler Error: {str(e)}"}

        # Run
        try:
            r_proc = subprocess.run(
                ['java', '-cp', tmpdir, class_name],
                input=input_str,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if r_proc.returncode != 0:
                return {'success': False, 'output': r_proc.stdout, 'error': r_proc.stderr or "Runtime Error"}
            return {'success': True, 'output': r_proc.stdout, 'error': None}
        except FileNotFoundError:
            return {'success': False, 'output': '', 'error': "Java Runtime (java) not found."}
        except subprocess.TimeoutExpired:
            return {'success': False, 'output': '', 'error': "Time Limit Exceeded"}
        except Exception as e:
            return {'success': False, 'output': '', 'error': f"Internal Execution Error: {str(e)}"}

def run_node(code, input_str, timeout):
    try:
        p = subprocess.run(
            ['node', '-e', code],
            input=input_str,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        if p.returncode != 0:
             return {'success': False, 'output': p.stdout, 'error': p.stderr}
        return {'success': True, 'output': p.stdout, 'error': None}
    except subprocess.TimeoutExpired:
        return {'success': False, 'output': '', 'error': "Time Limit Exceeded"}
    except:
        return {'success': False, 'output': '', 'error': "Node.js not found."}
