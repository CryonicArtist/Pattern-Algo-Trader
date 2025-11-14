from ultralytics import YOLO

# Define the name of the input PyTorch file
# (This file should be in the same directory)
pytorch_model_file = 'model.pt'

# Define the name of the output ONNX file
onnx_model_file = 'stockmarket-pattern-detection-yolov8.onnx'

try:
    # Load the PyTorch model
    print(f"Loading PyTorch model: {pytorch_model_file}...")
    model = YOLO(pytorch_model_file)
    print("Model loaded successfully.")

    # Export the model to ONNX format
    # We specify imgsz=640 to match the MATLAB script
    print(f"Exporting model to ONNX: {onnx_model_file}...")
    model.export(format='onnx', imgsz=640)

    print("\n---")
    print(f"Success! '{onnx_model_file}' has been created.")
    print("You can now run your MATLAB backtester.")
    print("---")

except FileNotFoundError:
    print(f"\n--- ERROR ---")
    print(f"File not found: {pytorch_model_file}")
    print("Please download 'model.pt' from the GitHub repository")
    print("and place it in the same folder as this script.")
    print("---")
except ImportError:
    print(f"\n--- ERROR ---")
    print("The 'ultralytics' library is not found.")
    print("Please install it by running:")
    print("pip install ultralytics")
    print("---")
except Exception as e:
    print(f"\n--- AN ERROR OCCURRED ---")
    print(e)
    print("---")