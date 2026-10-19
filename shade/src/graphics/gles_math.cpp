// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Provide matrix and vector operations for guest GLES transforms.

#include "graphics/gles_math.hpp"

#include <array>
#include <cmath>
#include <cstddef>
#include <utility>

namespace shade {

GlesMatrix::GlesMatrix()
    : values_ { 1.0F, 0.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F, 0.0F, 0.0F, 0.0F,
        1.0F, 0.0F, 0.0F, 0.0F, 0.0F, 1.0F }
{
}

GlesMatrix::GlesMatrix(std::array<float, 16> values)
    : values_ { std::move(values) }
{
}

GlesMatrix GlesMatrix::translation(float x, float y, float z)
{
    GlesMatrix result;
    result.values_[12] = x;
    result.values_[13] = y;
    result.values_[14] = z;
    return result;
}

GlesMatrix GlesMatrix::scale(float x, float y, float z)
{
    GlesMatrix result;
    result.values_[0] = x;
    result.values_[5] = y;
    result.values_[10] = z;
    return result;
}

GlesMatrix GlesMatrix::rotation(float degrees, float x, float y, float z)
{
    const auto length = std::sqrt(x * x + y * y + z * z);
    if (length == 0.0F)
        return GlesMatrix { };
    x /= length;
    y /= length;
    z /= length;
    constexpr float pi = 3.14159265358979323846F;
    const auto radians = degrees * pi / 180.0F;
    const auto cosine = std::cos(radians);
    const auto sine = std::sin(radians);
    const auto one_minus_cosine = 1.0F - cosine;
    return GlesMatrix { {
        x * x * one_minus_cosine + cosine,
        y * x * one_minus_cosine + z * sine,
        x * z * one_minus_cosine - y * sine,
        0.0F,
        x * y * one_minus_cosine - z * sine,
        y * y * one_minus_cosine + cosine,
        y * z * one_minus_cosine + x * sine,
        0.0F,
        x * z * one_minus_cosine + y * sine,
        y * z * one_minus_cosine - x * sine,
        z * z * one_minus_cosine + cosine,
        0.0F,
        0.0F,
        0.0F,
        0.0F,
        1.0F,
    } };
}

GlesMatrix GlesMatrix::orthographic(float left, float right, float bottom,
    float top, float near_value, float far_value)
{
    return GlesMatrix { {
        2.0F / (right - left),
        0.0F,
        0.0F,
        0.0F,
        0.0F,
        2.0F / (top - bottom),
        0.0F,
        0.0F,
        0.0F,
        0.0F,
        -2.0F / (far_value - near_value),
        0.0F,
        -(right + left) / (right - left),
        -(top + bottom) / (top - bottom),
        -(far_value + near_value) / (far_value - near_value),
        1.0F,
    } };
}

GlesMatrix GlesMatrix::frustum(float left, float right, float bottom, float top,
    float near_value, float far_value)
{
    return GlesMatrix { {
        2.0F * near_value / (right - left),
        0.0F,
        0.0F,
        0.0F,
        0.0F,
        2.0F * near_value / (top - bottom),
        0.0F,
        0.0F,
        (right + left) / (right - left),
        (top + bottom) / (top - bottom),
        -(far_value + near_value) / (far_value - near_value),
        -1.0F,
        0.0F,
        0.0F,
        -(2.0F * far_value * near_value) / (far_value - near_value),
        0.0F,
    } };
}

GlesMatrix GlesMatrix::operator*(const GlesMatrix& right) const
{
    std::array<float, 16> result { };
    for (std::size_t column = 0; column < 4; ++column) {
        for (std::size_t row = 0; row < 4; ++row) {
            for (std::size_t index = 0; index < 4; ++index) {
                result[column * 4U + row] += values_[index * 4U + row] *
                                             right.values_[column * 4U + index];
            }
        }
    }
    return GlesMatrix { result };
}

std::array<float, 4> GlesMatrix::transform(
    const std::array<float, 4>& vector) const
{
    std::array<float, 4> result { };
    for (std::size_t row = 0; row < 4; ++row) {
        for (std::size_t column = 0; column < 4; ++column) {
            result[row] += values_[column * 4U + row] * vector[column];
        }
    }
    return result;
}

} // namespace shade
