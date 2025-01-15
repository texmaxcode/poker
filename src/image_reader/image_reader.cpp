#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/highgui.hpp>
#include <iostream>

using namespace cv;

int show_image()
{
    std::string image_path = samples::findFile("buck.png");
    Mat img = imread(image_path, IMREAD_COLOR);
    if(img.empty())
    {
        std::cout << "Could not read the image: " << image_path << std::endl;
        return 1;
    }
    imshow("Display window", img);
    int key = waitKey(0); // Wait for a keystroke in the window
    if(key == 's')
    {
        imwrite("starry_night.png", img);
    }
    return 0;
}