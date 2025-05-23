#include <iostream>
#include <xdelta3/xdelta3.h>

int main() {
    std::cout << "Testing xdelta CMake configuration..." << std::endl;
    
    // Test basic xdelta functionality
    xd3_stream stream;
    xd3_config config;
    
    // Initialize configuration
    xd3_init_config(&config, XD3_ADLER32);
    
    // Initialize stream
    int ret = xd3_config_stream(&stream, &config);
    if (ret != 0) {
        std::cerr << "Failed to configure xdelta stream: " << ret << std::endl;
        return 1;
    }
    
    std::cout << "✅ xdelta library loaded and initialized successfully!" << std::endl;
    std::cout << "✅ CMake configuration is working correctly!" << std::endl;
    
    // Clean up
    xd3_free_stream(&stream);
    
    return 0;
}
