// Simple Kernel to tell the user we were successfully executed.

void main() {
    // Pointer to the first cell of our video memory (top-left of the screen).
    char* video_memory = (char*) 0xb8000;
    // Display an X to prove outselves that the Kernel was executed.
    *video_memory = 'X';
}