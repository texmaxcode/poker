#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/highgui.hpp>
#include <iostream>
#include <QDebug>

#include "image_reader.h"

using namespace cv;

void ImageReader::show_image()
{
    std::string image_path = samples::findFile("buck.png");
    Mat img = imread(image_path, IMREAD_COLOR);
    if(img.empty())
    {
        std::cout << "Could not read the image: " << image_path << std::endl;
    }
    imwrite("starry_night.png", img);
    qDebug() << "Saved the buck picture as starry night.";
}