"""Lossless FP16 -> FP32 output-interface casts; internal weights/compute stay FP16.

Run on macOS with coremltools==9.0. This uses Apple's supported MIL conversion
utility, not a hand-written modification of neural operations or weights.
"""
import sys
from pathlib import Path
import shutil
import coremltools as ct
from coremltools.proto.FeatureTypes_pb2 import ArrayFeatureType

source, destination = map(Path, sys.argv[1:3])
model = ct.models.MLModel(str(source), skip_model_load=True)
outputs = model.get_spec().description.output
if all(o.type.multiArrayType.dataType == ArrayFeatureType.FLOAT32 for o in outputs):
    shutil.copytree(source, destination, dirs_exist_ok=True)
else:
    converted = ct.utils.change_input_output_tensor_type(
        model,
        from_type=ArrayFeatureType.FLOAT16,
        to_type=ArrayFeatureType.FLOAT32,
        output_names=["low_res_masks", "scores"],
    )
    converted.save(str(destination))
print("Prepared FP32 decoder interface:", destination)
