// Simple Kernel to tell the user we were successfully executed.

void main() {
    // Pointer to the first cell of our video memory (top-left of the screen).
    char* video_memory = (char*) 0xb8000;
    char to_print[] = {"Hello from the Kernel!"};
    *video_memory = 'H';
    *(video_memory+1) = 0xff;
//     int j = 0;
    
//     for (int i = 0; i < 23; i++) {
//         j = i * 2;
//         *(video_memory+j) = to_print[i];
//         *(video_memory+j+1) = 0x0f;
//     }
}