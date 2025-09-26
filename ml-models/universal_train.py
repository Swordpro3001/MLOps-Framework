#!/usr/bin/env python3
"""
Universal ML Training Script
Works across all platforms with automatic GPU detection
"""

import os
import sys
import platform
import mlflow
import mlflow.sklearn
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
from sklearn.datasets import make_classification

def detect_compute_environment():
    """Detect available compute resources"""
    env_info = {
        'platform': platform.system(),
        'architecture': platform.machine(),
        'python_version': platform.python_version(),
        'gpu_available': False,
        'gpu_type': None
    }
    
    # Check for GPU availability
    try:
        import tensorflow as tf
        if tf.config.list_physical_devices('GPU'):
            env_info['gpu_available'] = True
            env_info['gpu_type'] = 'CUDA'
            print("✅ TensorFlow GPU detected")
        else:
            print("ℹ️ TensorFlow using CPU")
    except ImportError:
        try:
            import torch
            if torch.cuda.is_available():
                env_info['gpu_available'] = True
                env_info['gpu_type'] = 'CUDA'
                print("✅ PyTorch CUDA detected")
            else:
                print("ℹ️ PyTorch using CPU")
        except ImportError:
            print("ℹ️ No GPU ML libraries detected")
    
    return env_info

def train_model():
    """Universal model training function"""
    
    # Environment detection
    env_info = detect_compute_environment()
    print(f"🖥️ Platform: {env_info['platform']} {env_info['architecture']}")
    print(f"🐍 Python: {env_info['python_version']}")
    print(f"🔧 GPU Available: {env_info['gpu_available']}")
    
    # MLflow setup
    mlflow.set_tracking_uri(os.getenv('MLFLOW_TRACKING_URI', 'http://localhost:5000'))
    mlflow.set_experiment('universal-ml-experiment')
    
    with mlflow.start_run():
        # Log environment info
        mlflow.log_params(env_info)
        
        # Generate sample data
        print("📊 Generating sample dataset...")
        X, y = make_classification(
            n_samples=1000,
            n_features=10,
            n_informative=5,
            n_redundant=2,
            n_classes=2,
            random_state=42
        )
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Train model
        print("🤖 Training model...")
        model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=42
        )
        model.fit(X_train, y_train)
        
        # Evaluate model
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        # Log results
        mlflow.log_metric('accuracy', accuracy)
        mlflow.log_metric('train_samples', len(X_train))
        mlflow.log_metric('test_samples', len(X_test))
        
        # Log model
        mlflow.sklearn.log_model(
            model,
            "random_forest_model",
            registered_model_name="universal-ml-model"
        )
        
        print(f"✅ Model trained successfully!")
        print(f"📈 Accuracy: {accuracy:.4f}")
        print(f"🔍 Classification Report:")
        print(classification_report(y_test, y_pred))
        
        return accuracy

if __name__ == "__main__":
    train_model()
