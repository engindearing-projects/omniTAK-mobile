fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Compile protobuf definitions
    prost_build::Config::new()
        .compile_protos(&["proto/meshtastic.proto"], &["proto/"])?;

    Ok(())
}
