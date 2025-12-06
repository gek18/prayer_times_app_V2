set(AUDIO_FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/../assets/audio/abdulbasit.mp3
  ${CMAKE_CURRENT_SOURCE_DIR}/../assets/audio/mekkah.mp3
  ${CMAKE_CURRENT_SOURCE_DIR}/../assets/audio/mishary.mp3
  ${CMAKE_CURRENT_SOURCE_DIR}/../assets/audio/naseer.mp3
  ${CMAKE_CURRENT_SOURCE_DIR}/../assets/audio/notification.mp3
  ${CMAKE_CURRENT_SOURCE_DIR}/../assets/audio/yasir.mp3
)

foreach(file ${AUDIO_FILES})
  file(COPY ${file} DESTINATION ${CMAKE_BINARY_DIR}/Bundle)
endforeach()
