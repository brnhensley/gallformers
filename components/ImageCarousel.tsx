import React, { useState } from 'react';
import { Carousel } from 'nuka-carousel';
import { Modal } from 'react-bootstrap';
import { ImageApi } from '../libs/api/apitypes';

// Define the type for carousel images
export interface CarouselImage extends ImageApi {
    src: string;
    alt: string;
}

type ImageCarouselProps = {
    images: Array<CarouselImage>;
    renderContent: (image: CarouselImage, isModal: boolean, handleImageClick?: (index: number) => void) => React.ReactNode;
    onImageClick: (index: number, image: CarouselImage) => void;
    onSlideChange: (index: number, image: CarouselImage) => void;
};

const ImageCarousel = ({ images, onImageClick, onSlideChange, renderContent }: ImageCarouselProps) => {
    const [showModal, setShowModal] = useState(false);
    const [currentIndex, setCurrentIndex] = useState(0);

    const handleImageClick = (index: number) => {
        setCurrentIndex(index);
        setShowModal(true);
        onImageClick(index, images[index]);
    };

    const handleModalClose = () => {
        setShowModal(false);
    };

    const renderCarousel = (isModal = false) => {
        return (
            <Carousel
                showArrows={true}
                showDots={true}
                wrapMode="wrap"
                initialPage={currentIndex}
                keyboard={true}
                autoplay={false}
                beforeSlide={(_: number, endSlide: number) => {
                    setCurrentIndex(endSlide);
                    if (onSlideChange) {
                        onSlideChange(endSlide, images[endSlide]);
                    }
                }}
                className="carousel-container"
            >
                {images.map((image, index) => (
                    <div
                        key={image.id}
                        style={{
                            minWidth: '100%',
                            width: '100%',
                            height: '100%',
                            display: 'flex',
                            justifyContent: 'center',
                            alignItems: 'center',
                        }}
                    >
                        {renderContent(image, isModal, () => handleImageClick(index))}
                    </div>
                ))}
            </Carousel>
        );
    };

    return (
        <>
            <div style={{ position: 'relative' }}>{renderCarousel()}</div>

            <Modal
                show={showModal}
                onHide={handleModalClose}
                centered
                size="lg"
                dialogClassName="modal-90w"
                style={{
                    position: 'fixed',
                    paddingTop: '20px',
                    left: 0,
                    top: 0,
                    width: '100vw',
                    height: '95vh',
                    overflow: 'none',
                }}
            >
                <Modal.Header closeButton />
                <Modal.Body
                    style={{
                        position: 'relative',
                        margin: 'auto',
                        padding: 0,
                        width: '100%',
                        maxWidth: '1200px',
                    }}
                >
                    {renderCarousel(true)}
                </Modal.Body>
            </Modal>
        </>
    );
};

export default ImageCarousel;
